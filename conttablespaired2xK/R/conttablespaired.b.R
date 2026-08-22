
#' @importFrom jmvcore .
contTablesPairedClass <- R6::R6Class(
    "contTablesPairedClass",
    inherit = contTablesPairedBase,
    private = list(
        .cleanData = function() {

            rowVarName <- self$options$rows
            colVarName <- self$options$cols
            countsName <- self$options$counts

            data <- jmvcore::select(self$data, c(rowVarName, colVarName, countsName))
            data <- jmvcore::naOmit(data)

            if ( ! is.null(rowVarName))
                data[[rowVarName]] <- as.factor(data[[rowVarName]])
            if ( ! is.null(colVarName))
                data[[colVarName]] <- as.factor(data[[colVarName]])
            if ( ! is.null(countsName))
                data[[countsName]]  <- jmvcore::toNumeric(data[[countsName]])

            data
        },
        .init = function() {

            freqs <- self$results$get('freqs')
            rowVarName <- self$options$rows
            colVarName <- self$options$cols

            data <- private$.cleanData()

            if ( ! is.null(rowVarName))
                title <- rowVarName
            else
                title <- '.'

            freqs$addColumn(
                name=title,
                title=title,
                type='text')

            if ( ! is.null(colVarName)) {
                superTitle <- colVarName
                levels <- base::levels(data[[colVarName]])
            }
            else {
                superTitle <- '.'
                levels <- c('.', '.')
            }

            subNames  <- c('[count]', '[pcRow]', '[pcCol]', '[pcMarg]')
            subTitles <- c(.('Count'), .('% within row'), .('% within column'), .('% marginal'))
            visible   <- c('TRUE', '(pcRow)', '(pcCol)', '(pcMarg)')
            types     <- c('integer', 'number', 'number', 'number')
            formats   <- c('', 'pc', 'pc', 'pc')

            for (j in seq_along(subNames)) {
                subName <- subNames[[j]]
                if (j == 1)
                    v <- '(pcRow || pcCol || pcMarg)'
                else
                    v <- visible[j]

                freqs$addColumn(
                    name=paste0('type', subName),
                    title='',
                    type='text',
                    visible=v)
            }

            for (i in seq_along(levels)) {
                level <- levels[[i]]

                for (j in seq_along(subNames)) {
                    subName <- subNames[[j]]
                    # marginal % is only defined for the Total row/column,
                    # never for an individual cell -- see .run()
                    freqs$addColumn(
                        name=paste0(i, subName),
                        title=level,
                        superTitle=superTitle,
                        type=types[j],
                        format=formats[j],
                        visible=visible[j])
                }
            }

            freqs$addColumn(
                name='.total[count]',
                title=.('Total'),
                type='integer')

            freqs$addColumn(
                name='.total[pcRow]',
                title=.('Total'),
                type='number',
                format='pc',
                visible='(pcRow)')

            freqs$addColumn(
                name='.total[pcCol]',
                title=.('Total'),
                type='number',
                format='pc',
                visible='(pcCol)')

            freqs$addColumn(
                name='.total[pcMarg]',
                title=.('Total'),
                type='number',
                format='pc',
                visible='(pcMarg)')

            values <- list()
            for (i in seq_along(subNames))
                values[[paste0('type', subNames[i])]] <- subTitles[i]

            rows <- private$.grid(data, incRows=TRUE)

            for (i in seq_len(nrow(rows))) {
                for (name in dimnames(rows)[[2]]) {
                    value <- as.character(rows[i, name])
                    if (value == '.total')
                        value <- .('Total')
                    values[[name]] <- value
                }
                key <- paste0(rows[i,], collapse='`')
                freqs$addRow(rowKey=key, values=values)

                if (i == 1)
                    freqs$addFormat(rowNo=i, 1, Cell.BEGIN_GROUP)
                else if (i == nrow(rows) - 1)
                    freqs$addFormat(rowNo=i, 1, Cell.END_GROUP)
                else if (i == nrow(rows))
                    freqs$addFormat(rowNo=i, 1, Cell.BEGIN_END_GROUP)
            }

            test <- self$results$get('test')
            test$addRow(rowKey=1, values=list())

            odds <- self$results$get('odds')
            odds$addRow(rowKey=1, values=list())

            agree <- self$results$get('agree')
            agree$addRow(rowKey=1, values=list())

            ciText <- jmvcore::format(.('{ciWidth}% Confidence Intervals'), ciWidth=self$options$ciWidth)
            odds$getColumn('cil[dp]')$setSuperTitle(ciText)
            odds$getColumn('ciu[dp]')$setSuperTitle(ciText)
            odds$getColumn('cil[o]')$setSuperTitle(ciText)
            odds$getColumn('ciu[o]')$setSuperTitle(ciText)
            odds$getColumn('cil[oe]')$setSuperTitle(ciText)
            odds$getColumn('ciu[oe]')$setSuperTitle(ciText)
            agree$getColumn('cil[kap]')$setSuperTitle(ciText)
            agree$getColumn('ciu[kap]')$setSuperTitle(ciText)
            agree$getColumn('cil[obs]')$setSuperTitle(ciText)
            agree$getColumn('ciu[obs]')$setSuperTitle(ciText)
        },
        .run = function() {

            rowVarName <- self$options$rows
            colVarName <- self$options$cols
            countsName <- self$options$counts

            if (is.null(rowVarName) || is.null(colVarName))
                return()

            data <- private$.cleanData()

            if (nlevels(data[[rowVarName]]) < 2)
                jmvcore::reject(.("Row variable '{var}' contains fewer than 2 levels"), code='', var=rowVarName)
            if (nlevels(data[[colVarName]]) < 2)
                jmvcore::reject(.("Column variable '{var}' contains fewer than 2 levels"), code='', var=colVarName)

            if ( ! is.null(countsName)) {
                countCol <- jmvcore::toNumeric(data[[countsName]])

                if (any(countCol < 0, na.rm=TRUE))
                    jmvcore::reject(.('Counts may not be negative'))
                if (any(is.infinite(countCol)))
                    jmvcore::reject(.('Counts may not be infinite'))
            }

            rowVar <- data[[rowVarName]]
            colVar <- data[[colVarName]]

            freqs <- self$results$freqs
            test  <- self$results$test
            odds  <- self$results$odds
            agree <- self$results$agree

            if ( ! is.null(countsName))
                result <- stats::xtabs(countCol ~ rowVar + colVar)
            else
                result <- base::table(rowVar, colVar)

            N <- sum(result)
            colTotals <- apply(result, 2, base::sum)
            rowTotals <- apply(result, 1, base::sum)

            #### freqs table ####

            for (rowNo in seq_len(nrow(result))) {

                counts <- result[rowNo,]

                if (length(counts) > 0) {
                    rowTotal <- rowTotals[rowNo]
                    pcRow <- counts / rowTotal
                    pcCol <- counts / colTotals

                    names(counts) <- paste0(seq_len(length(counts)), '[count]')
                    names(pcRow)  <- paste0(seq_len(length(counts)), '[pcRow]')
                    names(pcCol)  <- paste0(seq_len(length(counts)), '[pcCol]')

                    values <- c(counts, pcRow, pcCol)
                    values <- as.list(values)

                    # marginal % is only meaningful for the row/column
                    # aggregate, not for an individual interior cell -- left
                    # blank ('', not NaN) rather than shown as "not a number"
                    pcMarg <- as.list(rep('', length(counts)))
                    names(pcMarg) <- paste0(seq_len(length(counts)), '[pcMarg]')
                    values <- c(values, pcMarg)

                    values[['.total[count]']] <- unname(rowTotal)
                    values[['.total[pcRow]']] <- 1
                    values[['.total[pcCol]']] <- unname(rowTotal) / N
                    values[['.total[pcMarg]']] <- unname(rowTotal) / N

                    freqs$setRow(rowNo=rowNo, values=values)
                }
            }

            nCols <- length(colTotals)
            freqRowNo <- nrow(result) + 1

            values <- as.list(colTotals)
            names(values) <- paste0(1:nCols, '[count]')
            values[['.total[count]']] <- N

            pcRow <- as.list(colTotals / N)
            names(pcRow) <- paste0(1:nCols, '[pcRow]')

            pcCol <- as.list(rep(1, nCols))
            names(pcCol) <- paste0(1:nCols, '[pcCol]')

            # on the Total row, [pcMarg] IS the column marginal % (the
            # quantity the difference-in-proportions / Stuart-Maxwell tests
            # compare), unlike the interior cells above
            pcMarg <- as.list(colTotals / N)
            names(pcMarg) <- paste0(1:nCols, '[pcMarg]')

            values <- c(values, pcRow, pcCol, pcMarg)
            values[['.total[pcRow]']] <- 1
            values[['.total[pcCol]']] <- 1
            values[['.total[pcMarg]']] <- 1

            freqs$setRow(rowNo=freqRowNo, values=values)

            #### shape checks ####

            nR <- nrow(result)
            nC <- ncol(result)
            square <- (nR == nC)
            is2x2 <- square && nR == 2
            isRxR <- square && nR > 2

            # discordant cells, used throughout the 2x2-only sections below
            if (is2x2) {
                b <- result[1,2]
                c <- result[2,1]
            }

            ciWidth <- self$options$ciWidth / 100
            tail <- (100 - self$options$ciWidth) / 200
            z <- qnorm(tail, lower.tail=FALSE)

            #### McNemar / Bowker (same statistic, routed by table shape) ####

            sym <- try(stats::mcnemar.test(result, correct=FALSE), silent=TRUE)
            wcor <- if (is2x2) try(stats::mcnemar.test(result, correct=TRUE), silent=TRUE) else NULL

            translateError <- function(err) {
                msg <- jmvcore::extractErrorMessage(err)
                if (msg == "'x' must be square with at least two rows and columns")
                    .('The table must be square (rows and columns must share the same categories)')
                else if (msg == "all entries of 'x' must be nonnegative and finite")
                    .('Counts must be non-negative and finite')
                else
                    msg
            }

            values <- list()

            if (base::inherits(sym, 'try-error') || is.na(sym$statistic)) {
                values[['value[mcn]']] <- NaN
                values[['df[mcn]']] <- ''
                values[['p[mcn]']]  <- ''
                values[['value[bow]']] <- NaN
                values[['df[bow]']] <- ''
                values[['p[bow]']]  <- ''
            } else {
                # Bowker's test of symmetry generalizes McNemar's chi-square
                # to RxR; stats::mcnemar.test() already computes Bowker's
                # formula whenever the table is square, so the SAME `sym`
                # object is the right answer for any square table, 2x2
                # included. For 2x2 it is numerically IDENTICAL to the
                # uncorrected chi-square (both rows show the same value) --
                # that equality is expected, not a display bug.
                values[['value[bow]']] <- unname(sym$statistic)
                values[['df[bow]']] <- unname(sym$parameter)
                values[['p[bow]']]  <- sym$p.value

                if (is2x2) {
                    values[['value[mcn]']] <- unname(sym$statistic)
                    values[['df[mcn]']] <- unname(sym$parameter)
                    values[['p[mcn]']]  <- sym$p.value
                } else {
                    values[['value[mcn]']] <- NaN
                    values[['df[mcn]']] <- ''
                    values[['p[mcn]']]  <- ''
                }
            }

            if (base::inherits(wcor, 'try-error') || is.null(wcor) || is.na(wcor$statistic)) {
                values[['value[cor]']] <- NaN
                values[['df[cor]']] <- ''
                values[['p[cor]']]  <- ''
            } else {
                values[['value[cor]']] <- unname(wcor$statistic)
                values[['df[cor]']] <- unname(wcor$parameter)
                values[['p[cor]']]  <- wcor$p.value
            }

            #### exact binomial test (2x2 only) ####

            if (is2x2) {
                bin <- try(stats::binom.test(b, b + c, 0.5), silent=TRUE)

                if (base::inherits(bin, 'try-error')) {
                    values[['value[bin]']] <- NaN
                    values[['p[bin]']] <- ''
                } else {
                    values[['value[bin]']] <- ''
                    values[['p[bin]']] <- bin$p.value
                }
            } else {
                values[['value[bin]']] <- NaN
                values[['p[bin]']] <- ''
                bin <- NULL
            }
            values[['df[bin]']] <- ''

            #### Stuart-Maxwell (any square table; reduces to McNemar's ####
            #### chi-square for 2x2, same as Bowker's test above) ####

            if (square) {
                sm <- try(private$.stuartMaxwell(result), silent=TRUE)
                if (base::inherits(sm, 'try-error') || is.na(sm$statistic)) {
                    values[['value[sm]']] <- NaN
                    values[['df[sm]']] <- ''
                    values[['p[sm]']]  <- ''
                } else {
                    values[['value[sm]']] <- sm$statistic
                    values[['df[sm]']] <- sm$df
                    values[['p[sm]']]  <- sm$p.value
                }
            } else {
                sm <- NULL
                values[['value[sm]']] <- NaN
                values[['df[sm]']] <- ''
                values[['p[sm]']]  <- ''
            }

            values[['value[n]']] <- N

            test$setRow(rowNo=1, values=values)

            if (base::inherits(sym, 'try-error')) {
                error <- translateError(sym)
                test$addFootnote(rowNo=1, 'value[mcn]', error)
                test$addFootnote(rowNo=1, 'value[bow]', error)
            }
            if ( ! square) {
                notSquareMsg <- .('The table must be square (rows and columns must share the same categories)')
                test$addFootnote(rowNo=1, 'value[mcn]', notSquareMsg)
                test$addFootnote(rowNo=1, 'value[bow]', notSquareMsg)
                test$addFootnote(rowNo=1, 'value[cor]', notSquareMsg)
                test$addFootnote(rowNo=1, 'value[bin]', notSquareMsg)
                test$addFootnote(rowNo=1, 'value[sm]', notSquareMsg)
            } else if (isRxR) {
                only2x2Msg <- .('Available for 2x2 tables only')
                test$addFootnote(rowNo=1, 'value[mcn]', only2x2Msg)
                test$addFootnote(rowNo=1, 'value[cor]', only2x2Msg)
                test$addFootnote(rowNo=1, 'value[bin]', only2x2Msg)
            }

            if (is2x2 && (b + c) > 0 && (b + c) < 25 && self$options$chiSq && ! self$options$exactBinom) {
                test$addFootnote(rowNo=1, 'p[mcn]', .('Few discordant pairs ({n}) — consider the exact test (binomial)', n=b + c))
            }

            #### Comparative Measures (2x2 only): odds ratio + diff. in proportions ####
            #
            # Reference = the first category, for BOTH rows and columns (the
            # same convention as conttables2xK): rows/cols level 2 is the
            # "effect" category. b = mat[1,2] (reference -> effect), c =
            # mat[2,1] (effect -> reference); OR = b/c is the odds, among
            # discordant pairs, that a pair moves TOWARD the effect category
            # rather than away from it. DP = (b - c) / N is the difference
            # between the two marginal "effect" proportions (column margin
            # minus row margin).

            if (is2x2) {

                oddsValues <- list()

                if (self$options$diffProp) {
                    dp <- private$.diffPropPaired(result, z)
                    oddsValues[['v[dp]']] <- dp$dp
                    oddsValues[['cil[dp]']] <- dp$lower
                    oddsValues[['ciu[dp]']] <- dp$upper
                }

                if (self$options$oddsRatio) {
                    orRes <- private$.pairedOR(b, c, z)
                    oddsValues[['v[o]']] <- orRes$or
                    oddsValues[['cil[o]']] <- orRes$lower
                    oddsValues[['ciu[o]']] <- orRes$upper
                    if (orRes$corrected) {
                        odds$addFootnote(rowNo=1, 'v[o]', .('Haldane-Anscombe correction applied (a discordant cell is zero)'))
                    }
                }

                if (self$options$oddsExact) {
                    if ( ! requireNamespace('exact2x2', quietly=TRUE)) {
                        stop(.('exact2x2 must be installed to calculate an exact odds ratio'), call.=FALSE)
                    }
                    ex <- try(exact2x2::exact2x2(result, paired=TRUE, conf.level=ciWidth), silent=TRUE)
                    if (base::inherits(ex, 'try-error') || is.na(ex$estimate)) {
                        oddsValues[['v[oe]']] <- NaN
                        oddsValues[['cil[oe]']] <- ''
                        oddsValues[['ciu[oe]']] <- ''
                        odds$addFootnote(rowNo=1, 'v[oe]', .('Could not be computed'))
                    } else {
                        oddsValues[['v[oe]']] <- unname(ex$estimate)
                        oddsValues[['cil[oe]']] <- ex$conf.int[1]
                        oddsValues[['ciu[oe]']] <- ex$conf.int[2]
                    }
                }

                referenceFootnote <- .('Reference is the first category, for rows and columns')
                if (self$options$diffProp)
                    odds$addFootnote(rowNo=1, 'v[dp]', referenceFootnote)
                if (self$options$oddsRatio)
                    odds$addFootnote(rowNo=1, 'v[o]', referenceFootnote)
                if (self$options$oddsExact)
                    odds$addFootnote(rowNo=1, 'v[oe]', referenceFootnote)

                odds$setRow(rowNo=1, values=oddsValues)

            } else {

                unavailMsg <- .('Available for 2x2 tables only')
                oddsValues <- list(
                    `v[dp]`=NaN, `cil[dp]`='', `ciu[dp]`='',
                    `v[o]`=NaN, `cil[o]`='', `ciu[o]`='',
                    `v[oe]`=NaN, `cil[oe]`='', `ciu[oe]`='')
                odds$setRow(rowNo=1, values=oddsValues)
                odds$addFootnote(rowNo=1, 'v[dp]', unavailMsg)
                odds$addFootnote(rowNo=1, 'v[o]', unavailMsg)
                odds$addFootnote(rowNo=1, 'v[oe]', unavailMsg)
            }

            #### Agreement (any square table) ####

            agreeValues <- list()

            if ( ! square) {

                unavailMsg <- .('The table must be square (rows and columns must share the same categories)')
                agreeValues <- list(
                    `v[obs]`=NaN, `cil[obs]`='', `ciu[obs]`='',
                    `v[kap]`=NaN, `cil[kap]`='', `ciu[kap]`='')
                agree$setRow(rowNo=1, values=agreeValues)
                agree$addFootnote(rowNo=1, 'v[obs]', unavailMsg)
                agree$addFootnote(rowNo=1, 'v[kap]', unavailMsg)

            } else {

                if (self$options$agreement) {
                    concordant <- sum(diag(result))
                    agreeValues[['v[obs]']] <- concordant / N

                    propTest <- try(stats::prop.test(concordant, N, conf.level=ciWidth, correct=FALSE), silent=TRUE)
                    if (base::inherits(propTest, 'try-error')) {
                        agreeValues[['cil[obs]']] <- ''
                        agreeValues[['ciu[obs]']] <- ''
                    } else {
                        agreeValues[['cil[obs]']] <- propTest$conf.int[1]
                        agreeValues[['ciu[obs]']] <- propTest$conf.int[2]
                    }
                }

                if (self$options$kappa) {
                    kap <- try(vcd::Kappa(result), silent=TRUE)
                    if (base::inherits(kap, 'try-error')) {
                        agreeValues[['v[kap]']] <- NaN
                        agreeValues[['cil[kap]']] <- ''
                        agreeValues[['ciu[kap]']] <- ''
                        agree$addFootnote(rowNo=1, 'v[kap]', .('Could not be computed'))
                    } else {
                        agreeValues[['v[kap]']] <- unname(kap$Unweighted['value'])
                        ci <- confint(kap, level=ciWidth)
                        agreeValues[['cil[kap]']] <- ci['Unweighted', 'lwr']
                        agreeValues[['ciu[kap]']] <- ci['Unweighted', 'upr']
                    }
                }

                agree$setRow(rowNo=1, values=agreeValues)
            }
        },
        .grid = function(data, incRows=FALSE) {

            rowVarName <- self$options$get('rows')

            expand <- list()

            if (incRows) {
                if (is.null(rowVarName))
                    expand[['.']] <- c('.', '. ', .('Total'))
                else
                    expand[[rowVarName]] <- c(base::levels(data[[rowVarName]]), '.total')
            }

            rows <- rev(expand.grid(expand))

            rows
        },
        .diffPropPaired = function(mat, z) {
            # Difference between the two marginal ("effect", i.e. second
            # category) proportions of a paired 2x2 table, with the standard
            # Wald confidence interval for correlated proportions (Fleiss).
            # mat is the RAW row x column table (NOT re-oriented): b =
            # mat[1,2], c = mat[2,1] are the discordant cells.

            b <- mat[1,2]
            c <- mat[2,1]
            n <- sum(mat)

            dp <- (b - c) / n
            se <- sqrt((b + c) - (b - c)^2 / n) / n

            list(dp=dp, lower=dp - z * se, upper=dp + z * se)
        },
        .pairedOR = function(b, c, z) {
            # Wald confidence interval for the paired (conditional) odds
            # ratio b/c, on the log scale. Haldane-Anscombe correction
            # (+0.5 to each discordant cell) when either is zero.

            corrected <- (b == 0 || c == 0)
            bb <- if (corrected) b + 0.5 else b
            cc <- if (corrected) c + 0.5 else c

            logOR <- log(bb / cc)
            se <- sqrt(1 / bb + 1 / cc)

            list(or=bb / cc, lower=exp(logOR - z * se), upper=exp(logOR + z * se), corrected=corrected)
        },
        .stuartMaxwell = function(mat) {
            # Stuart-Maxwell test of marginal homogeneity: the RxR
            # generalization of the difference-in-proportions test.
            # Drops the last category (marginal differences sum to zero, so
            # only k-1 are independent); statistic = d' S^-1 d, df = k-1.

            k <- nrow(mat)
            r <- rowSums(mat)
            c <- colSums(mat)
            d <- (r - c)[1:(k - 1)]

            S <- matrix(0, k - 1, k - 1)
            for (i in seq_len(k - 1)) {
                S[i, i] <- r[i] + c[i] - 2 * mat[i, i]
                for (j in seq_len(k - 1)) {
                    if (i != j)
                        S[i, j] <- -(mat[i, j] + mat[j, i])
                }
            }

            statistic <- as.numeric(t(d) %*% solve(S) %*% d)
            df <- k - 1
            p.value <- 1 - pchisq(statistic, df)

            list(statistic=statistic, df=df, p.value=p.value)
        },
        .sourcifyOption = function(option) {
            if (option$name %in% c('rows', 'cols', 'counts'))
                return('')
            super$.sourcifyOption(option)
        },
        .formula = function() {
            if (is.null(self$options$rows) || is.null(self$options$cols))
                return('~')
            jmvcore:::composeFormula(self$options$counts, list(list(self$options$rows, self$options$cols)))
        })
)
