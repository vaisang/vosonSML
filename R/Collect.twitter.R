#' @title Collect tweet data from twitter search
#'
#' @description This function collects tweet data based on search terms and structures the data into a dataframe with 
#' the class names \code{"datasource"} and \code{"twitter"}.
#'
#' The twitter Standard search API sets a rate limit of 180 requests every 15 minutes. A maximum of 100 tweets can be 
#' collected per search request meaning the maximum number of tweets per operation is 18000 / 15 minutes. More tweets 
#' can be collected by using \code{retryOnRateLimit = TRUE} parameter which will cause the collection to pause if the 
#' rate limit is reached and resume when the rate limit resets (in approximately 15 minutes). Alternatively the twitter 
#' API parameter \code{since_id} can be used in a later session to resume a twitter search collection from the last 
#' tweet previously collected as tweet status id's are sequential. The Standard API only returns tweets for the last 
#' 7 days.
#' 
#' All of the search query operators available through the twitter API can be used in the \code{searchTerm} field. 
#' For example, to search for tweets containing the term \code{"love"} or \code{"hate"} the \code{"OR"} operator can be 
#' used in the term field: \code{searchTerm = "love OR hate"}. For more information refer to the twitter API 
#' documentation for query operators: \url{https://developer.twitter.com/en/docs/tweets/search/guides/standard-operators}.
#'
#' @note Additional parameters passed to this function in the ellipsis \code{...} will also be passed to the Twitter 
#' search API request. Most parameters have been covered but a complete list can be found here: 
#' \url{https://developer.twitter.com/en/docs/tweets/search/api-reference/get-search-tweets}
#' A useful additional parameter is \code{language} allowing the user can restrict tweets returned to a particular 
#' language using an ISO 639-1 code. For example, to restrict a search to tweets in English the value 
#' \code{language = "en"} can be passed to this function.
#' 
#' @param credential A \code{credential} object generated from \code{Authenticate} with class name \code{"twitter"}.
#' @param searchTerm Character string. Specifies a twitter search term. For example, \code{"Australian politics"} or 
#' the hashtag \code{"#auspol"}.
#' @param searchType Character string. Returns filtered tweets as per search type \code{recent}, \code{mixed} or 
#' \code{popular}. Default type is \code{recent}.
#' @param numTweets Numeric. Specifies how many tweets to be collected. Defaults is \code{100}.
#' @param includeRetweets Logical. Specifies if the search should filter out retweets. Defaults is \code{TRUE}.
#' @param retryOnRateLimit Logical. Default is \code{FALSE}.
#' @param writeToFile Logical. Write collected data to file. Default is \code{FALSE}.
#' @param verbose Logical. Output additional information about the data collection. Default is \code{FALSE}.
#' @inheritDotParams rtweet::search_tweets -token -q -n -type -include_rts -retryonratelimit -verbose
#' 
#' @return A data.frame object with class names \code{"datasource"} and \code{"twitter"}.
#' 
#' @examples
#' \dontrun{
#' # search and collect 100 recent tweets for the hashtag #auspol
#' myTwitterData <- twitterAuth %>% 
#'   Collect(searchTerm = "#auspol", searchType = "recent", numTweets = 100, verbose = TRUE, 
#'           includeRetweets = FALSE, retryOnRateLimit = TRUE, writeToFile = TRUE)
#' }
#' 
#' @export
Collect.twitter <- function(credential, searchTerm = "", searchType = "recent", numTweets = 100, 
                            includeRetweets = TRUE, retryOnRateLimit = FALSE, writeToFile = FALSE, 
                            verbose = FALSE, ...) {
 
  authToken <- credential$auth
  
  if (!("Token" %in% class(authToken))) { 
    stop("OAuth token missing. Please use the Authenticate function to create and supply a token.", call. = FALSE)
  }
  
  searchTerm <- trimws(searchTerm)
  cat(paste0("Collecting tweets", ifelse(searchTerm == "", "", paste0(" for search term: ", searchTerm)), "...\n"))
  flush.console()
  
  rtlimit <- rtweet::rate_limit(authToken, "search/tweets")
  remaining <- rtlimit[["remaining"]] * 100
  if (retryOnRateLimit == TRUE & numTweets < remaining) {
    cat(paste0("Requested ", numTweets, " tweets of ", remaining, " in this rate limit.\n"))
    cat("Less tweets requested than remaining limit retryOnRateLimit set to FALSE.\n")
    retryOnRateLimit <- FALSE
  }
  
  search_params <- list()
  search_params[['token']] <- authToken
  
  search_params['q'] <- searchTerm
  search_params['type'] <- searchType
  search_params['n'] <- numTweets
  search_params['include_rts'] <- includeRetweets
  search_params['retryonratelimit'] <- retryOnRateLimit
  search_params['verbose'] <- verbose
  
  # additional twitter api params
  dots <- substitute(...())
  search_params[['...']] <- dots
  
  tweets_df <- do.call(rtweet::search_tweets, search_params)
  
  cat(paste0("Collected ", nrow(tweets_df), " tweets.\n"))
  
  # rds chosen over csv to avoid flattening lists in the data
  if (writeToFile) { writeOutputFile(tweets_df, "rds", "TwitterData") }
  
  cat("Done.\n")
  flush.console()
  
  class(tweets_df) <- append(class(tweets_df), c("datasource", "twitter"))
  
  return(tweets_df)
}
