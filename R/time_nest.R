#' Nest a `tbl_time` to a specified time period
#'
#' `time_nest` allows for quick nesting of `tbl_time` objects by period so that
#' manipulation can be performed on each period's data set individually. See
#' [tidyr::nest()] for information on nesting generally.
#'
#' @inheritParams time_group
#' @inheritParams tidyr::nest
#' @param data A `tbl_time` object.
#' @param keep_inner_dates Whether to add dates to each nested object as the
#' column, `.date`.
#' @param ... Used to specify columns you do not want in the nest. Specified
#' as `-col_name`.
#'
#' @details
#'
#' As an example, nesting by a `"yearly"` period will return a `tbl_time` object
#' with a date column containing the dates at the end of each year, and a
#' list-column of smaller `tbl_time` objects containing all of the data for
#' that year.
#'
#' Because it is likely the case that the original dates will be required
#' inside the nested `tbl_time` objects for further manipulation,
#' the original dates are kept as a `.date` column in each `tbl_time` object in
#' the list-column.
#'
#' This function respects [dplyr::group_by()] groups.
#'
#'
#' @examples
#'
#' # Basic functionality -------------------------------------------------------
#'
#' data(FB)
#' FB <- as_tbl_time(FB, date)
#'
#' # Nest yearly
#' time_nest(FB, "yearly")
#'
#' # Nest yearly, but don't drag symbol into the nest
#' time_nest(FB, "yearly", -symbol)
#'
#' # Nest quarterly
#' time_nest(FB, "quarterly")
#'
#' # Grouped functionality -----------------------------------------------------
#'
#' data(FANG)
#' FANG <- as_tbl_time(FANG, date) %>%
#'   dplyr::group_by(symbol)
#'
#' # Nest yearly, but by group
#' FANG %>%
#'   time_nest("yearly")
#'
#' @export
#'
time_nest <- function(data, period = "yearly", ..., .key = "data", keep_inner_dates = TRUE) {
  UseMethod("time_nest")
}

#' @export
#'
time_nest.default <- function(data, period = "yearly", ..., .key = "data", keep_inner_dates = TRUE) {
  stop("Object is not of class `tbl_time`.", call. = FALSE)
}

#' @export
#'
time_nest.tbl_time <- function(data, period = "yearly", ..., .key = "data", keep_inner_dates = TRUE) {

  # Setup
  cols_not_nested <- retrieve_index(data, as_name = TRUE)
  .key     <- rlang::enquo(.key)
  .key_sym <- rlang::sym(rlang::quo_name(.key))

  # Collapse. Keeping sep column for the old dates
  data_coll <- time_collapse(data, period, as_sep_col = keep_inner_dates)

  # Nest, allowing for user specified columns in ...
  data_coll <- tidyr::nest(data_coll, ...,
                           - dplyr::one_of(cols_not_nested),
                           .key = !! .key)

  if(keep_inner_dates) {
    # Each element in the nest should be a tbl_time
    data_coll <- dplyr::mutate(data_coll,
                  !! .key_sym := purrr::map(!! .key_sym,
                                            ~as_tbl_time(.x, .date)))
  }

  data_coll

}

#' @export
#'
time_nest.grouped_tbl_time <- function(data, period = "yearly",
                                       ..., .key = "data", keep_inner_dates = TRUE) {

  # Setup
  cols_not_nested <- c(dplyr::group_vars(data),
                       retrieve_index(data, as_name = TRUE))
  .key     <- rlang::enquo(.key)
  .key_sym <- rlang::sym(rlang::quo_name(.key))

  # Collapse. Keeping sep column for the old dates
  data_coll <- time_collapse(data, period, as_sep_col = keep_inner_dates)

  data_coll <- data_coll %>%

    # Enforce ungrouping
    dplyr::ungroup() %>%

    # Nest, allowing for user specified columns in ...
    tidyr::nest(..., - dplyr::one_of(cols_not_nested), .key = !! .key)

  if(keep_inner_dates) {
    # Each element in the nest should be a tbl_time
    data_coll <- dplyr::mutate(data_coll,
                               !! .key_sym := purrr::map(!! .key_sym,
                                                         ~as_tbl_time(.x, .date)))
  }

  data_coll
}
