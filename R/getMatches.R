globalVariables(c('V2', 'V3', '.'))

#' getMatches
#'
#' Subset two data frames to the matches returned by \code{fastLink()}
#' or \code{matchesLink()}. Can also return a single deduped data frame
#' if dfA and dfB are identical and fl.out is of class 'fastLink.dedupe'.
#'
#' @usage getMatches(dfA, dfB, fl.out, threshold.match, combine.dfs)
#' @param dfA Dataset A - matched to Dataset B by \code{fastLink()}.
#' @param dfB Dataset B - matches to Dataset A by \code{fastLink()}.
#' @param fl.out Either the output from \code{fastLink()} or \code{matchesLink()}.
#' @param threshold.match A number between 0 and 1 indicating the lower bound that the
#' user wants to declare a match. For instance, threshold.match = .85 will return all pairs with posterior probability greater than .85 as matches.
#' Default is 0.85.
#' @param combine.dfs Whether to combine the two data frames being merged into a single data frame. If FALSE, two data frames are returned in a list. Default is TRUE.
#'
#' @return \code{getMatches()} returns a list of two data frames:
#' \item{dfA.match}{A subset of \code{dfA} subsetted down to the successful matches.}
#' \item{dfB.match}{A subset of \code{dfB} subsetted down to the successful matches.}
#'
#' @author Ben Fifield  <benfifield@gmail.com>
#'
#' @examples
#' \dontrun{
#' fl.out <- fastLink(dfA, dfB,
#' varnames = c("firstname", "lastname", "streetname", "birthyear"),
#' n.cores = 1)
#' ret <- getMatches(dfA, dfB, fl.out)
#' }
#' @export
getMatches <- function(dfA, dfB, fl.out, threshold.match = 0.85, combine.dfs = TRUE){

    ## Convert data frames
    if(any(class(dfA) %in% c("tbl_df", "data.table"))){
        dfA <- as.data.frame(dfA)
    }
    if(any(class(dfB) %in% c("tbl_df", "data.table"))){
        dfB <- as.data.frame(dfB)
    }

    if(inherits(fl.out, "fastLink.dedupe") & !identical(dfA, dfB)){
        stop("You have provided a fastLink object from deduping a single data frame, but dfA and dfB are not identical. Please check your inputs.")
    }
    if(identical(dfA, dfB) & !inherits(fl.out, "fastLink.dedupe")){
        stop("dfA and dfB are identical, but fl.out is not of class 'fastLink.dedupe.' Please check your inputs.")
    }

    ## Depending on class
    if(inherits(fl.out, "matchesLink")){
        dfA.match <- dfA[fl.out$inds.a,]
        dfB.match <- dfB[fl.out$inds.b,]
        if(combine.dfs){
            names.dfB <- names(dfB.match)[!(names(dfB.match) %in% names(dfA.match))]
            if(length(names.dfB) > 0){
                df.match <- cbind(dfA.match, dfB.match[,names.dfB])
            }else{
                df.match <- dfA.match
            }
            out <- df.match
        }else{
            out <- list(dfA.match = dfA.match, dfB.match = dfB.match)
        }
    }else if(inherits(fl.out, "fastLink.dedupe")){

        ## Get ID
        id_tmp <- data.frame(id = 1:nrow(dfA))

        ## Get matches
        matches <- data.table(
            cbind(
                fl.out$matches$inds.b[fl.out$posterior >= threshold.match],
                fl.out$matches$inds.a[fl.out$posterior >= threshold.match]
            )
        )
        
        temp0 <- 1:nrow(dfA)
        temp1 <- which(!(temp0 %in% matches$V1))
        
        if(length(temp1) > 0) {
            temp2 <- cbind(as.matrix(temp1), as.matrix(temp1))
            matches <- rbind(matches, temp2)
        }

        pasteT <- function(x) {
            x = sort(x) # 1,2,3 is the same as 3,2,1
            x = paste(x, collapse = ",") 
            x
        }

        ## Dedupe
        matches[, V3 := pasteT(V2), by = "V1"]    
        ans <- matches[, .(id_2 = unique(V3)), by = "V1"]
        ans$id_2 <- as.numeric(as.factor(ans$id_2))
        colnames(ans) <- c("id", "id_2")

        ## Merge and output new df
        out_df <- merge(id_tmp, ans, by = "id")
        dfA$dedupe.ids <- out_df$id_2
        out <- dfA
        
        
    }else{
        dfA.match <- dfA[fl.out$matches$inds.a,]
        dfB.match <- dfB[fl.out$matches$inds.b,]
        if(combine.dfs){
            names.dfB <- names(dfB.match)[!(names(dfB.match) %in% names(dfA.match))]
            if(length(names.dfB) > 0){
                df.match <- cbind(dfA.match, dfB.match[,names.dfB])
            }else{
                df.match <- dfA.match
            }
            df.match <- cbind(df.match, fl.out$patterns)
            if("posterior" %in% names(fl.out)){
                df.match$posterior <- fl.out$posterior
                df.match <- df.match[df.match$posterior >= threshold.match,]
            }
            out <- df.match
        }else{
            dfA.match <- cbind(dfA.match, fl.out$patterns)
            dfB.match <- cbind(dfB.match, fl.out$patterns)
            if("posterior" %in% names(fl.out)){
                dfA.match$posterior <- fl.out$posterior
                dfB.match$posterior <- fl.out$posterior
                dfA.match <- dfA.match[dfA.match$posterior >= threshold.match,]
                dfB.match <- dfB.match[dfB.match$posterior >= threshold.match,]
            }
            out <- list(dfA.match = dfA.match, dfB.match = dfB.match)
        }
    }

    return(out)
    
}

