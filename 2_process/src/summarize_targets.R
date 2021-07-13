summarize_targets <- function(ind_file, targets_to_summarize) {
  ind_tbl <- tar_meta(all_of(targets_to_summarize)) %>%
    select(tar_name = name, filepath = path, hash = data) %>%
    mutate(filepath = unlist(filepath))

  readr::write_csv(ind_tbl, ind_file)
  return(ind_file)
}
