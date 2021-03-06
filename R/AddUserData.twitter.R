#' @title Enhances twitter actor network graph by adding user attributes to nodes
#'
#' @description Creates a network from the relations and users dataframes generated by Create. Network is supplemented with 
#' additional downloaded twitter user information applied as node attributes.
#'
#' @note Only supports twitter actor network at this time. Bimodal network support could be achieved by the filtering 
#' of the twitter user ids from nodes of other types in the \code{networkData}. Refer to S3 methods 
#' \code{\link{Authenticate.twitter}}, \code{\link{Collect.twitter}} and \code{\link{Create.actor.twitter}} to first 
#' create twitter actor network and data to pass as input into this function.
#' 
#' @param collectData A dataframe containing the collected tweet data from the \code{Collect} function.
#' @param networkData A named list containing the relations \code{$relations} and users \code{$users} data returned 
#' from the \code{Create} actor network function.
#' @param lookupUsers Logical. Lookup user profile information using the twitter API for any users data missing from 
#' the collect data set. For example fetches profile information for users that became nodes during network creation 
#' because they were mentioned in a tweet but did not author any tweets themselves. Default is \code{TRUE}.
#' @param twitterAuth A twitter authentication object from \code{Authenticate}.
#' @param writeToFile Logical. If \code{TRUE} a data frame of user information and the resulting network graph will 
#' be written to file in \code{rds} and \code{graphml} formats respectively. Default is \code{FALSE}.
#'
#' @return A named list containing a dataframe with user information \code{$users} and an igraph object of the twitter 
#' actor network with supplemental user node attributes \code{$graph}.
#'
#' @examples
#' \dontrun{
#' # add additional twitter user profile information to actor network graph as node attributes 
#' # requires twitterAuth from Authenticate, twitterData from Collect and actorNetwork from 
#' # Create actor network
#' actorNetWithUserAttr <- AddUserData.twitter(twitterData, actorNetwork,
#'                                             lookupMissingUsers = TRUE, 
#'                                             twitterAuth = twitterAuth, writeToFile = TRUE)
#' # igraph object
#' # actorNetWithUserAttr$graph
#' }
#' 
#' @aliases AddUserData.twitter
#' @name vosonSML::AddUserData.twitter
#' @export
AddUserData.twitter <- function(collectData, networkData, lookupUsers = TRUE, twitterAuth = NULL, writeToFile = FALSE) {
  
  dfCollect <- collectData
  dfRelations <- networkData$relations
  dfUsers <- networkData$users
  
  if (is.null(dfRelations) || is.null(dfUsers)) {
    stop("Missing relations or users network data.", call. = FALSE) 
  }
  
  cat("Creating twitter network graph with user information as node attributes...\n")
  flush.console()
  
  dfUsers %<>% dplyr::mutate_all(as.character) # changes all col types to character
  
  df_users_info <- rtweet::users_data(dfCollect) %>% dplyr::distinct(.data$user_id, .keep_all = TRUE)
  df_users_info %<>% dplyr::mutate_all(as.character) # changes all col types to character
  df_missing_users <- dplyr::anti_join(dfUsers, df_users_info, by = "user_id") %>% 
    dplyr::distinct(.data$user_id, .keep_all = TRUE)
  
  df_missing_users_info <- NULL
  if (lookupUsers) {
    if (is.null(twitterAuth)) {
      cat("Please supply rtweet twitter authentication token to look up missing users info.\n")
    } else {
      cat(paste0("Fetching user information for ", nrow(df_missing_users), " users.\n"))
      
      # 90000 users per 15 mins with unused rate limit
      df_lookup_data <- rtweet::lookup_users(df_missing_users$user_id, parse = TRUE, 
                                             token = twitterAuth$auth)
      df_missing_users_info <- rtweet::users_data(df_lookup_data)
      cat(paste0("User information collected for ", nrow(df_missing_users_info), " users.\n"))
      
      if (nrow(df_missing_users) != nrow(df_missing_users_info)) {
        cat("Collected user records does not match the number requested. Adding incomplete records back in.\n")
        df_not_collected <- dplyr::anti_join(df_missing_users, df_missing_users_info, by = "user_id")
        df_missing_users_info <- dplyr::bind_rows(df_missing_users_info, df_not_collected)
      }
    }
  } else {
    cat("No additional users information fetched.\n")
  }
  
  if (!is.null(df_missing_users_info)) {
    df_users_info_all <- rbind(df_users_info, df_missing_users_info)
  } else {
    df_users_info_all <- dplyr::bind_rows(df_users_info, df_missing_users)
  }
  
  df_users_info_all %<>% dplyr::rename("display_name" = .data$name, "name" = .data$user_id)
  
  # fix type for numeric value columns and also replace na values with zero for convenience
  # numeric value column names in rtweet collected data end with "count"
  df_users_info_all %<>% dplyr::mutate_at(vars(ends_with("count")), funs(ifelse(is.na(.data$.), as.integer(0), 
                                                                         as.integer(.data$.))))
  
  if (!is.null(df_missing_users_info) & writeToFile) {
    writeOutputFile(df_users_info_all, "rds", "TwitterUserData")
  }
  
  g <- graph_from_data_frame(dfRelations, directed = TRUE, vertices = df_users_info_all)

  V(g)$screen_name <- ifelse(is.na(V(g)$screen_name), paste0("ID:", V(g)$name), V(g)$screen_name)
  V(g)$label <- V(g)$screen_name
  
  if (writeToFile) { writeOutputFile(g, "graphml", "TwitterUserNetwork") }
  
  cat("Done.\n")
  flush.console()
  
  func_output <- list(
    "users" = df_users_info_all,
    "graph" = g
  )
  
  return(func_output)
}
