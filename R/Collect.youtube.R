#' @title Collect comments data for youtube videos
#'
#' @description This function collects public comments data for one or more youtube videos using the YouTube Data API 
#' v3 and structures the data into a dataframe with the class names \code{"datasource"} and \code{"youtube"}.
#' 
#' Youtube has a quota unit system as a rate limit with most developers having either 10,000 or 1,000,000 units per 
#' day. Many read operations cost a base of 1 unit such as retrieving individual comments, plus 1 or 2 units for text 
#' snippets. Retrieving threads or top-level comments with text costs 3 units per request (maximum 100 comments per 
#' request). Using this function a video with 250 top-level comments and 10 of those having reply comments of up to 100 
#' each, should cost (9 + 20) 29 quota units and return between 260 and 1260 total comments. There is currently a limit 
#' of 100 reply comments collected per video thread.
#' 
#' More information about the YouTube Data API v3 can be found here: 
#' \url{https://developers.google.com/youtube/v3/getting-started}
#' 
#' @note Due to specifications of the YouTube Data API it is currently not efficient to specify the exact number of 
#' comments to return from the API using \code{maxComments} parameter. The \code{maxComments} parameter is applied to
#' top-level comments only and not the replies to these comments. As such the number of comments collected is usually 
#' greater than expected. For example, if \code{maxComments} is set to 10 and one of the videos 10 top-level comments 
#' has 5 reply comments then the total number of comments collected will be 15 for that video. Comments data for 
#' multiple youtube videos can be requested in a single operation, \code{maxComments} is applied to each individual 
#' video and not the combined total of comments.
#' 
#' To help extract video ids for videos the function \code{\link{GetYoutubeVideoIDs}} can be used. It accepts input of 
#' a vector or file containing video urls and creates a chracter vector suitable as input for the \code{videoIDs} 
#' parameter.
#' 
#' @param credential A \code{credential} object generated from \code{Authenticate} with class name \code{"youtube"}.
#' @param videoIDs Character vector. Specifies one or more youtube video IDs. For example, if the video URL is 
#' \code{https://www.youtube.com/watch?v=xxxxxxxxxxx} then use \code{videoIDs = c("xxxxxxxxxxx")}.
#' @param verbose Logical. Output additional information about the data collection. Default is \code{FALSE}.
#' @param writeToFile Logical. Write collected data to file. Default is \code{FALSE}.
#' @param maxComments Numeric integer. Specifies how many top-level comments to collect from each video. This value 
#' does not consider replies to top-level comments. The total number of comments returned for a video will usually be 
#' greater than \code{maxComments} depending on the number of reply comments present.
#' @param ... Additional parameters passed to function. Not used in this method.
#' 
#' @return A data.frame object with class names \code{"datasource"} and \code{"youtube"}.
#' 
#' @examples
#' \dontrun{
#' # create a list of youtube video ids to collect on
#' videoIDs <- GetYoutubeVideoIDs(c("https://www.youtube.com/watch?v=xxxxxxxx", 
#'                                  "https://youtu.be/xxxxxxxx"))
#' 
#' # collect approximately 200 threads/comments for each youtube video
#' youtubeData <- youtubeAuth %>% 
#'   Collect(videoIDs = videoIDs, writeToFile = TRUE, verbose = FALSE, maxComments = 200)
#' }
#' 
#' @export
Collect.youtube <- function(credential, videoIDs, verbose = FALSE, writeToFile = FALSE, 
                            maxComments = 10000000000000, ...) {
  
  # maxComments defaults to an arbitrary very large number
  
  apiKey <- credential$auth
  if (is.null(apiKey) || nchar(apiKey) < 1) {
    stop("Please provide a valid youtube api key.", call. = FALSE)
  }
  
  if (missing(videoIDs) || !is.vector(videoIDs) || length(videoIDs) < 1) {
    stop("Please provide a vector of one or more youtube video ids.", call. = FALSE)
  }
    
  # Start data collection
  
  # Create a dataframe to iteratively store comments from all the videos that the user wants to scrape 
  # (i.e. specified in videoIDs) uses 'dummy' data in first row (which is removed later)
  dataCombined <- data.frame(Comment = "foo",
                             User = "bar",
                             ReplyCount = "99999999",
                             LikeCount = "99999999",
                             PublishTime = "timestamp",
                             CommentId = "99999999123456789",
                             ParentID = "foobar",
                             ReplyToAnotherUser = "FALSE",
                             VideoID = "foobarfoobar",
                             stringsAsFactors = FALSE)
  
  # Iterate through the videos in videoIDs, adding to dataCombined.
  for (k in 1:length(videoIDs)) {
    cat(paste0("Collecting video number: ", k, " of ", length(videoIDs), "\n", sep = "")) # DEBUG
    cat("---------------------------------------------------------------\n")
    
    ############################## Collect comment threads #############################
    
    rObj <- yt_scraper(videoIDs, apiKey, k, verbose)
    
    rObj$scrape_all(maxComments)

    ## Make a dataframe out of the results
    
    if (verbose) { cat(paste0("** Creating dataframe from threads of ", videoIDs[k], ".\n", sep = "")) }
    
    tempData <- lapply(rObj$data, function(x) {
      data.frame(Comment = x$snippet$topLevelComment$snippet$textDisplay,
                 User = x$snippet$topLevelComment$snippet$authorDisplayName,
                 ReplyCount = x$snippet$totalReplyCount,
                 LikeCount = x$snippet$topLevelComment$snippet$likeCount,
                 PublishTime = x$snippet$topLevelComment$snippet$publishedAt,
                 CommentId = x$snippet$topLevelComment$id,
                 ParentID = "None",
                 ReplyToAnotherUser = "FALSE",
                 VideoID = videoIDs[k], # actual reference to API data is: 
                                        # x$snippet$topLevelComment$snippet$videoIDs[k]
                 stringsAsFactors = FALSE)
    })
    
    core_df <- do.call("rbind", tempData)
      
    ############################## Collect comment replies #############################
    
    commentIDs <- core_df$CommentId
    
    # only attempt to collect replies for comments we know have replies
    commentIDs_with_replies <- core_df[which(core_df$ReplyCount > 0), ] # column 6
    commentIDs_with_replies <- commentIDs_with_replies$CommentId
    
    cat(paste0("** Collecting replies for ", length(commentIDs_with_replies), 
               " threads with replies. Please be patient.\n", sep = "")) # commentIDs
    
    base_url <- "https://www.googleapis.com/youtube/v3/comments"
    
    # 'dummy' first row of dataframe, for DEBUG purposes (fix later..)
    dataRepliesAll <- data.frame(Comment = "foo",
                                 User = "bar",
                                 ReplyCount = "99999999",
                                 LikeCount = "99999999",
                                 PublishTime = "timestamp",
                                 CommentId = "99999999123456789",
                                 ParentID = "foobar",
                                 ReplyToAnotherUser = "FALSE",
                                 VideoID = videoIDs[k], # API DOESN'T SEEM TO RETURN HERE, no matter anyway
                                 stringsAsFactors = FALSE)

    # for each thread 
    # ** doesnt have paging - possibly wont get all comments if > 100 per thread
    # need to do same as with threads
    total_replies <- 0
    for (i in 1:length(commentIDs_with_replies)) { # commentIDs
      api_opts <- list(part = "snippet",
                       textFormat = "plainText",
                       parentId=commentIDs_with_replies[i], # commentIDs
                       key = apiKey)
      
      init_results <- httr::content(httr::GET(base_url, query = api_opts)) # TODO: should die when there is error
      
      num_items <- length(init_results$items)
      
      if (verbose) {
        if (i == 1) {
          cat("Comment replies ")
        }
        
        cat(paste(num_items, ""))
        flush.console()
      } else {
        cat(".")
        flush.console()        
      }
        
      total_replies <- total_replies + num_items
      
      tempDataReplies <- lapply(init_results$items, function(x) {
        data.frame(Comment = x$snippet$textDisplay,
                   User = x$snippet$authorDisplayName,
                   ReplyCount = 0, # there is no ReplyCount returned for replies (API specs)
                   LikeCount = x$snippet$likeCount,
                   PublishTime = x$snippet$publishedAt,
                   CommentId = x$id,
                   ParentID = x$snippet$parentId,
                   ReplyToAnotherUser = "FALSE",
                   VideoID = videoIDs[k], # API DOESN'T SEEM TO RETURN HERE, not that it matters
                   stringsAsFactors = FALSE)
      })
      
      tempDataRepliesBinded <- do.call("rbind", tempDataReplies)
      
      dataRepliesAll <- rbind(dataRepliesAll, tempDataRepliesBinded)
    }
    
    cat(paste0("\n** Collected replies: ", total_replies, "\n", sep = ""))
    cat(paste0("** Total video comments: ", length(commentIDs) + total_replies, "\n", sep = ""))
    cat("---------------------------------------------------------------\n")
    
    ############################## Combine comment threads and replies #############################
      
    # get rid of "dummy" first row
    dataRepliesAll <- dataRepliesAll[-1, ]
    
    # combine the comments and replies dataframes
    dataCombinedTemp <- rbind(core_df, dataRepliesAll)
    
    # APPEND TO THE OVERALL DATAFRAME (I.E. MULTIPLE VIDEO COMMENTS)
    dataCombined <- rbind(dataCombined, dataCombinedTemp)
  }
    
  cat(paste0("** Total comments collected for all videos ", nrow(dataCombined)-1, ".\n", sep = ""))
  
  # Remove 'dummy' first row
  dataCombined <- dataCombined[-1, ]
  
  ## Throw Error when no comment can be collected
  if (nrow(dataCombined) == 0) {
    stop(paste0("No comments could be collected from the given video Ids: ", videoIDs, "\n", sep = ""))
  }

  if (verbose) {
    cat("Cleaning and structuring data. Please be patient.\n")
  }
  
  ############################## Map relations between users into dataframe #############################
  
  ## For each commentsDataNames element, if any commentTexts elements pattern matches
  ## with a commentsDataNames element, then it is a reply/mention:
  
  # isReplyToAnotherUser <- c(rep("FALSE",length(dataCombined$Comment)))
  isReplyToAnotherUser <- dataCombined[, 8]
  
  ### !!!!! Escape any punctuation characters in names when using GREP!!!
  ## From: http://stackoverflow.com/questions/14836754/is-there-an-r-function-to-escape-a-string-for-regex-characters
  ## This uses an R implementation of Perl's `quotemeta` function
  
  usernamesCleaned <- dataCombined$User # vector of user names (speed + readability)
  commentsTextCleaned <- dataCombined$Comment # duplicate of comment text data (speed + readability)
  
  # This function is from the library("Hmisc")
  usernamesCleaned <- escapeRegex(usernamesCleaned)
  
  # NEW WAY (OPTIMISED - better, faster, stronger...)
  dataCombined$ReplyToAnotherUser <- SearchCommentsForMentions(commentsTextCleaned, usernamesCleaned)
  
  ## Map the comment replies within PARENT COMMENT THREADS into dataframe
  
  parentsTemp <- which(dataCombined[, 7] != "None" & dataCombined[, 8] == "FALSE")
  
  if (length(parentsTemp) != 0) {
    for (i in 1:nrow(dataCombined[parentsTemp, ])) {
      
      # take the 1st match - we could try to scrape MULTIPLE REPLIES/MENTIONS, but would require re-think.
      tempMatch <- which(dataCombined[parentsTemp[i], 7] == dataCombined[, 6])[1] 
      dataCombined[parentsTemp[i], 8] <- dataCombined[tempMatch, 2]
      
    }
  }
  
  if (writeToFile) { writeOutputFile(dataCombined, "csv", "YoutubeData") }
    
  cat("Done.\n")
  flush.console()
  
  #############################################################################
  # return dataframe to environment
  
  class(dataCombined) <- append(class(dataCombined), c("dataource", "youtube"))
  
  return(dataCombined)
  
  #############################################################################
}

## Set up a class and methods/functions for scraping
yt_scraper <- setRefClass(
  "yt_scraper", 
  fields = list(
    base_url = "character",
    api_opts = "list",
    nextPageToken = "character",
    page_count = "numeric",
    data = "list",
    unique_count = "numeric",
    done = "logical",
    core_df = "data.frame",
    verbose = "logical"),
  
  methods = list(
    # collect api results for page
    scrape = function() {
      
      # set default api request options
      opts <- api_opts
      
      if (is.null(nextPageToken) | length(trimws(nextPageToken)) == 0L | trimws(nextPageToken) == "") {
        if (page_count >= 1) {
          if (verbose) {
            cat(paste0("-- No nextPageToken. Returning. page_count is: ", page_count, "\n"))
          }
          # return no threads collected to signal done
          return(0)
        } else {
          if (verbose) {
            cat("-- First thread page. No pageToken.\n")
          }
        }
      } else {
        opts$pageToken <- trimws(nextPageToken)
        
        if (verbose) {
          cat(paste0("-- Value of pageToken: ", opts$pageToken, "\n"))
        }
      }
      
      page_count <<- page_count + 1
      
      res <- httr::content(httr::GET(base_url, query = opts))
      
      if (is.null(res$nextPageToken)) {
        nextPageToken <<- ""
      } else {
        nextPageToken <<- res$nextPageToken
      }
      
      # add threads to data list
      data <<- c(data, res$items)
      
      # return count of threads collected from page
      return(length(res$items))
    },
    
    # collect all video threads until done or max comments reached
    scrape_all = function(maxComments) {
      cat(paste0("** video Id: ", api_opts$videoId ,"\n", sep = ""))
      if (verbose) {
        cat(paste0("   [results per page: ", api_opts$maxResults, " | max comments per video: ", maxComments, "]\n", 
                   sep = ""))
      }
      
      thread_count <- 0
      
      while (TRUE) {
        # collect threads for current page
        thread_count <- scrape()
        
        if (verbose) {
          cat(paste0("-- Collected threads from page: ", thread_count, "\n", sep = ""))
        }        
        
        if (thread_count == 0 | length(data) > maxComments) {
          done <<- TRUE
          nextPageToken <<- ""
          
          if (length(data) > maxComments) {
            cat(paste0("-- API returned more than max comments. Results truncated to first ", maxComments, 
                       " threads.\n", sep = ""))
            
            data <<- data[1:maxComments]
          }
          
          if (verbose) { cat(paste0("-- Done collecting threads.\n", sep = "")) }
          
          break
        }
      }
      if (verbose) {
        cat(paste0("** Results page count: ", page_count, "\n", sep = ""))
      }
      cat(paste0("** Collected threads: ", length(data), "\n", sep = ""))
    },
    
    # quota cost approx 1 per commentThreads + 2 for snippet part, 3 per page of results
    initialize = function(videoIDs, apiKey, k, verbose = FALSE) {
      base_url <<- "https://www.googleapis.com/youtube/v3/commentThreads/"
      api_opts <<- list(part = "snippet",
                        maxResults = 100,
                        textFormat = "plainText",
                        videoId = videoIDs[k],
                        key = apiKey,
                        fields = "items,nextPageToken",
                        orderBy = "published")
      page_count <<- 0
      nextPageToken <<- ""
      data <<- list()
      unique_count <<- 0
      done <<- FALSE
      core_df <<- data.frame()
      verbose <<- verbose
    },
    
    reset = function() {
      data <<- list()
      page_count <<- 0
      nextPageToken <<- ""
      unique_count <<- 0
      done <<- FALSE
      core_df <<- data.frame()
    },
    
    cache_core_data = function() {
      if (nrow(core_df) < unique_count) {
        sub_data <- lapply(data, function(x) {
          data.frame(
            Comment = x$snippet$topLevelComment$snippet$textDisplay,
            User = x$snippet$topLevelComment$snippet$authorDisplayName,
            ReplyCount = x$snippet$totalReplyCount,
            LikeCount = x$snippet$topLevelComment$snippet$likeCount,
            PublishTime = x$snippet$topLevelComment$snippet$publishedAt,
            CommentId = x$snippet$topLevelComment$id,
            stringsAsFactors = FALSE)
        })
        core_df <<- do.call("rbind", sub_data)
      } else {
        message("core_df is already up to date.\n")
      }
    }
  )
)
