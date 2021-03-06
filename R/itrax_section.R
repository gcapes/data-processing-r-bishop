#' Cluster analysis and statistical grouping of Itrax data
#'
#' Performs a cluster analysis and automatic statistical grouping of parsed Itrax results data to n groups.
#' Also provides information on the most "representative" (central) of each group. These can be used to develop a
#' sub-sampling regime for calibration using another method.
#'
#' @param dataframe pass the name of a dataframe parsed using \code{"itrax_import()"} or \code{"itrax_join()"}
#' @param elementsonly if TRUE, only chemical elements are included. If FALSE, the data is passed unfiltered, otherwise a character vector of desired variable names can be supplied
#' @param zeros if "addone", adds one to all values. If "limit", replaces zero values with 0.001. Otherwise a function can be supplied to remove zero values.
#' @param transform binary operator that if TRUE will center-log-transform the data, if FALSE will leave the data untransformed. Otherwise, a function can be supplied to transform the data.
#' @param divisions the number of groups to slice into - also the number of representative samples returned
#' @param plot set to true if a summary plot is required as a side-effect - the input dataset must have a depth or position variable - depth is used preferentially.
#'
#' @importFrom tidyr drop_na
#' @importFrom stats prcomp hclust dist cutree
#' @importFrom compositions clr
#' @importFrom rlang .data
#'
#' @return either an output of \code{prcomp()}, or a list including the input data
#'
#' @examples
#' itrax_section(CD166_19_S1$xrf, plot = TRUE)
#'
#' @export
#'

itrax_section <- function(dataframe,
                          divisions = 30,
                          elementsonly = TRUE,
                          zeros = "addone",
                          transform = TRUE,
                          plot = FALSE){

  # fudge to stop check notes
  . = NULL
  group = NULL
  ids = NULL
  position = NULL

  # label with ids
  dataframe$ids <- 1:dim(dataframe)[1]
  input_dataframe <- dataframe

  # use internal function to do multivariate data preparation
  dataframe <- multivariate_import(dataframe = dataframe,
                                   elementsonly = elementsonly,
                                   zeros = zeros,
                                   transform = transform)

  # perform the first ordering
  firstorder <- as_tibble(dataframe) %>%
    mutate(group = dataframe %>%
             as.matrix() %>%
             dist() %>%
             hclust(method = "ward.D2") %>%
             cutree(k=divisions) %>%
             as.factor()) %>%
    select(`ids`, `group`)

  # perform second ordering
  rep_samples <- lapply(unique(firstorder$group), function(x){
    # subset a second order group
  second_order_subset <- as_tibble(dataframe) %>%
    mutate(group = firstorder$group) %>%
    filter(group == x)

  # perform another ordering of them and subset
  second_order_subset <- second_order_subset %>%
     mutate(group = second_order_subset %>%
             select(-`group`, `ids`) %>%
             as.matrix() %>%
             dist() %>%
             hclust(method = "ward.D2") %>%
             .$order
            ) %>%
    filter(group == round(mean(`group`))) %>%
    pull(`ids`)
  })

  rep_samples <- rep_samples %>%
    unlist()

  rep_samples <- input_dataframe %>%
    filter(`ids` %in% rep_samples) %>%
    select(-`ids`)

  # do a plot if required
  if(is.logical(plot) == TRUE && plot == TRUE){
    if("depth" %in% colnames(rep_samples) == TRUE){
    print(ggplot() +
            geom_bar(data = right_join(firstorder, input_dataframe, by = "ids"),
                     aes(x = depth, fill = as.factor(group)),
                     width = 1) +
            geom_point(data = rep_samples,
                       aes(x = depth),
                       y = 0.5,
                       shape = 3) +
            scale_x_reverse() +
            theme(axis.title.y = element_blank(),
                  axis.text.y = element_blank(),
                  axis.ticks.y = element_blank(),
                  legend.position = "none")
          )
    } else if("depth" %in% colnames(rep_samples) == FALSE && "position" %in% colnames(rep_samples) == TRUE){
      print(ggplot() +
              geom_bar(data = right_join(firstorder, input_dataframe, by = "ids"),
                       aes(x = position, fill = as.factor(group)),
                       width = 1) +
              geom_point(data = rep_samples,
                         aes(x = position),
                         y = 0.5,
                         shape = 3) +
              scale_x_reverse() +
              theme(axis.title.y = element_blank(),
                    axis.text.y = element_blank(),
                    axis.ticks.y = element_blank(),
                    legend.position = "none")
            )
      } else(stop("if plot = TRUE, you must include either a depth or position parameter"))
  } else if(is.logical(plot) == FALSE){
    stop("plot parameter must be logical (TRUE/FALSE)")
  }

  # sort the return
  return(list(groups = right_join(firstorder, input_dataframe, by = "ids") %>%
                select(-`ids`),
              samples = rep_samples))
}


