
library(targets)
library(tarchetypes)
library(tibble)
library(dplyr)

options(tidyverse.quiet = TRUE)
tar_option_set(packages = c("tidyverse", "dataRetrieval", "urbnmapr", "rnaturalearth", "cowplot", "lubridate"))

# Load functions needed by targets below
source("1_fetch/src/find_oldest_sites.R")
source("1_fetch/src/get_site_data.R")
source("2_process/src/tally_site_obs.R")
source("2_process/src/summarize_targets.R")
source("3_visualize/src/map_sites.R")
source("3_visualize/src/plot_data_coverage.R")
source("3_visualize/src/plot_site_data.R")

# Configuration
states <- c('WI','MN','MI', 'IL', 'IN', 'IA')
parameter <- c('00060')

# Define static branching before targets list
mapped_by_state_targets <-
  # Pull data for each state's oldest site
  tar_map(
    values = tibble(state_abb = states) %>%
      mutate(state_plot_files = sprintf("3_visualize/out/timeseries_%s.png", state_abb)),
    tar_target(nwis_inventory, filter(oldest_active_sites, state_cd == state_abb)),
    tar_target(nwis_data, get_site_data(nwis_inventory, state_abb, parameter)),
    # Insert step for tallying data here
    tar_target(tally, tally_site_obs(nwis_data)),
    # Insert step for plotting data here
    tar_target(timeseries_png, plot_site_data(state_plot_files, nwis_data, parameter), format="file"),
    names = state_abb,
    unlist = FALSE
  )

# Targets list

list(

  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),

  # Branch by state
  mapped_by_state_targets,

  # Combine the tally branches
  tar_combine(
    obs_tallies,
    mapped_by_state_targets$tally,
    command = combine_obs_tallies(!!!.x)
  ),

  tar_combine(
    summary_state_timeseries_csv,
    mapped_by_state_targets$timeseries_png,
    command = summarize_targets('3_visualize/log/summary_state_timeseries.csv', !!!.x),
    format="file"
  ),

  # Plot all years, all states observation tallies
  tar_target(
    data_coverage_png,
    plot_data_coverage(obs_tallies, "3_visualize/out/data_coverage.png", parameter),
    format = "file"
  ),

  # Map oldest sites
  tar_target(
    site_map_png,
    map_sites("3_visualize/out/site_map.png", oldest_active_sites),
    format = "file"
  )
)
