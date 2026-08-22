testthat::context('contTablesPairedOR')

testthat::test_that('2x2 tests, comparative measures and agreement match oracle values', {

    # classic paired-survey example (1st survey x 2nd survey), used as the
    # worked example in the .a.yaml docs: chi2=17.4 (uncorrected), 16.8
    # (corrected) -- cross-checked directly against base R stats::mcnemar.test,
    # stats::binom.test, and exact2x2::exact2x2(paired=TRUE)
    dat <- data.frame(
        s1 = factor(c('Approve', 'Approve', 'Disapprove', 'Disapprove'), c('Approve', 'Disapprove')),
        s2 = factor(c('Approve', 'Disapprove', 'Approve', 'Disapprove'), c('Approve', 'Disapprove')),
        n  = c(794, 150, 86, 570))

    r <- mcnemarOR::contTablesPairedOR(
        data=dat, rows='s1', cols='s2', counts='n',
        chiSq=TRUE, chiSqCorr=TRUE, exactBinom=TRUE,
        oddsRatio=TRUE, oddsExact=TRUE, diffProp=TRUE,
        agreement=TRUE, kappa=TRUE)

    freqs <- r$freqs$asDF
    testthat::expect_equal(freqs[['.total[count]']], c(944, 656, 1600))
    testthat::expect_equal(unname(unlist(freqs[3, c('1[count]', '2[count]')])), c(880, 720))

    test <- r$test$asDF
    testthat::expect_equal(test[['value[mcn]']], 17.355932, tolerance=1e-5)
    testthat::expect_equal(test[['df[mcn]']], 1)
    testthat::expect_equal(test[['value[cor]']], 16.817797, tolerance=1e-5)
    testthat::expect_equal(test[['p[bin]']], 3.715936e-05, tolerance=1e-6)
    testthat::expect_true(is.nan(test[['value[bow]']]))
    testthat::expect_true(is.nan(test[['value[sm]']]))
    testthat::expect_equal(test[['value[n]']], 1600)

    odds <- r$odds$asDF
    testthat::expect_equal(odds[['v[o]']], 150 / 86, tolerance=1e-9)
    testthat::expect_equal(odds[['cil[o]']], 1.338017, tolerance=1e-5)
    testthat::expect_equal(odds[['ciu[o]']], 2.273653, tolerance=1e-5)
    testthat::expect_equal(odds[['v[oe]']], 1.744186, tolerance=1e-5)
    testthat::expect_equal(odds[['cil[oe]']], 1.329228, tolerance=1e-5)
    testthat::expect_equal(odds[['ciu[oe]']], 2.300979, tolerance=1e-5)
    testthat::expect_equal(odds[['v[dp]']], (150 - 86) / 1600, tolerance=1e-9)

    agree <- r$agree$asDF
    testthat::expect_equal(agree[['v[obs]']], (794 + 570) / 1600, tolerance=1e-9)
    testthat::expect_equal(agree[['v[kap]']], 0.6995927, tolerance=1e-5)
    testthat::expect_equal(agree[['cil[kap]']], 0.6643542, tolerance=1e-5)
    testthat::expect_equal(agree[['ciu[kap]']], 0.7348312, tolerance=1e-5)
})

testthat::test_that('marginal percentages are blank on interior cells, populated on the totals', {

    dat <- data.frame(
        s1 = factor(c('Approve', 'Approve', 'Disapprove', 'Disapprove'), c('Approve', 'Disapprove')),
        s2 = factor(c('Approve', 'Disapprove', 'Approve', 'Disapprove'), c('Approve', 'Disapprove')),
        n  = c(794, 150, 86, 570))

    r <- mcnemarOR::contTablesPairedOR(data=dat, rows='s1', cols='s2', counts='n', pcMarg=TRUE)
    freqs <- r$freqs$asDF

    testthat::expect_true(all(is.nan(freqs[['1[pcMarg]']][1:2])))
    testthat::expect_true(all(is.nan(freqs[['2[pcMarg]']][1:2])))
    testthat::expect_equal(freqs[['.total[pcMarg]']][1:2], c(944 / 1600, 656 / 1600))
    testthat::expect_equal(unname(unlist(freqs[3, c('1[pcMarg]', '2[pcMarg]')])), c(880 / 1600, 720 / 1600))
})

testthat::test_that('RxR tables get Bowker/Stuart-Maxwell and kappa, not OR/DP', {

    # cross-checked against DescTools::StuartMaxwellTest (chi-sq=0.31718,
    # df=2, p=0.8533) and stats::mcnemar.test (chi-sq=0.38803, df=3,
    # p=0.9427, which for R>2 IS Bowker's test of symmetry)
    mat3 <- matrix(c(20, 5, 3, 4, 25, 6, 2, 7, 15), nrow=3, byrow=TRUE)
    lv <- c('A', 'B', 'C')
    dat <- data.frame(
        r1 = factor(rep(lv, each=3), lv),
        r2 = factor(rep(lv, times=3), lv),
        n  = as.vector(t(mat3)))

    r <- mcnemarOR::contTablesPairedOR(
        data=dat, rows='r1', cols='r2', counts='n',
        symmetry=TRUE, margHom=TRUE, oddsRatio=TRUE, diffProp=TRUE, kappa=TRUE)

    test <- r$test$asDF
    testthat::expect_equal(test[['value[bow]']], 0.38803088, tolerance=1e-5)
    testthat::expect_equal(test[['df[bow]']], 3)
    testthat::expect_equal(test[['value[sm]']], 0.3171806, tolerance=1e-5)
    testthat::expect_equal(test[['df[sm]']], 2)

    odds <- r$odds$asDF
    testthat::expect_true(is.nan(odds[['v[o]']]))
    testthat::expect_true(is.nan(odds[['v[dp]']]))

    agree <- r$agree$asDF
    testthat::expect_equal(agree[['v[obs]']], 60 / 87, tolerance=1e-9)
})

testthat::test_that('a non-square table degrades gracefully (no error, NaN + footnotes)', {

    dat <- data.frame(
        r1 = factor(c('A', 'A', 'B', 'B', 'C', 'C'), c('A', 'B', 'C')),
        r2 = factor(c('X', 'Y', 'X', 'Y', 'X', 'Y'), c('X', 'Y')),
        n  = c(10, 5, 3, 12, 7, 8))

    r <- mcnemarOR::contTablesPairedOR(data=dat, rows='r1', cols='r2', counts='n')

    test <- r$test$asDF
    testthat::expect_true(is.nan(test[['value[mcn]']]))
    testthat::expect_true(is.nan(test[['value[bow]']]))
    testthat::expect_equal(test[['value[n]']], 45)

    agree <- r$agree$asDF
    testthat::expect_true(is.nan(agree[['v[obs]']]))
})
