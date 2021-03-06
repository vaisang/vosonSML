#' @title Create youtube actor network
#' 
#' @description Creates a youtube actor network from comment threads on youtube videos. Users who have made comments to 
#' a video (top-level comments) and users who have replied to those comments are actor nodes. The comments are 
#' represented as directed edges between the actors. The video id is also included as an actor node, representative of 
#' the videos publisher with top-level comments as directed edges towards them. 
#' 
#' @param datasource Collected social media data with \code{"datasource"} and \code{"youtube"} class names.
#' @param type Character string. Type of network to be created, set to \code{"actor"}.
#' @param writeToFile Logical. Save network data to a file in the current working directory. Default is \code{FALSE}.
#' @param ... Additional parameters passed to function. Not used in this method.
#' 
#' @return Named list containing generated network as igraph object \code{$graph}.
#' 
#' @examples
#' \dontrun{
#' # create a youtube actor network graph
#' actorNetwork <- youtubeData %>% Create("actor", writeToFile = TRUE)
#' 
#' # igraph object
#' # actorNetwork$graph
#' }
#' 
#' @export
Create.actor.youtube <- function(datasource, type, writeToFile = FALSE, ...) {

  df_comments <- datasource # match the variable names to avoid warnings in package compilation

  cat("Generating youtube actor network...\n")
  flush.console()
  
  if (nrow(df_comments) == 0) {
    stop(paste0("There are no user comments in the data. Please check that the videos selected ",
               "for collection have comments."), call. = FALSE)
  }
  
  # direct comments which are not replies to others to a video id node
  # in the graph the video nodes will appear as VIDEO:AbCxYz where AbCxYz is the id
  not_replies <- which(df_comments$ReplyToAnotherUser == "FALSE" & df_comments$ParentID == "None")
  df_comments$ReplyToAnotherUser[not_replies] <- paste0("VIDEO:", df_comments$VideoID[not_replies])

  comment_users <- df_comments[, 2]
  mentioned_users <- df_comments[, 8]
  comment_ids <- df_comments[, 6]

  # create network of users that commented on videos as from user, to user, comment id
  df_actor_network <- data.frame(comment_users, mentioned_users, comment_ids)

  # make a vector of all the unique actors in the network
  actor_names <- unique(factor(c(as.character(unique(df_actor_network[, 1])),
                                 as.character(unique(df_actor_network[, 2])))))

  # make a dataframe of the relations between actors
  relations <- data.frame(from = df_actor_network[, 1], to = df_actor_network[, 2], commentId = df_actor_network[, 3])

  # convert into a graph
  g <- graph_from_data_frame(relations, directed = TRUE, vertices = actor_names)

  # add node labels
  V(g)$label <- V(g)$name
  g <- set_graph_attr(g, "type", "youtube")

  # output the final network to a graphml file
  if (writeToFile) { writeOutputFile(g, "graphml", "YoutubeActorNetwork") }

  cat("Done.\n")
  flush.console()

  func_output <- list(
    "graph" = g
  )
  
  class(func_output) <- append(class(func_output), c("network", "actor", "youtube"))
  
  return(func_output)
}
