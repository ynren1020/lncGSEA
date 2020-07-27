#' Single lncRNA Gene Set Enrichment Analysis
#'
#' TCGA samples are either stratified by lncRNA's expression and then calculate
#' logFC of high vs low express groups, or calculate correlation of genes' expression
#' with lncRNA's expression, genes are ordered by logFC or correlation coefficent
#' from largest to smallest. The pre-ranked file is used for pre-ranked GSEA using fgsea
#'
#' @param tid_cohort A output of data frame from pre_gsea function
#' @param cohort A string of character, showing one of TCGA studies
#' @param t_id A string of character, showing transcript id, same as pre_gsea
#' @param metric A string of character, showing which metric is used for rank
#' @param cor.method "pearson" or "spearman" method for cor metric
#' @param genelist TRUE or FALSE for output ordered gene list or not
#' @param geneset A string of character, showing the path where gmt is
#' @param pathway A string of character, showing one of pathway in the gmt file
#'
#'
#' @import tibble
#' @import fgsea
#' @import data.table
#'
#' @return A dataframe showing the GSEA results,if pathway is not null, its enrichment plot
#'         will be produced too.
#'
#' @example
#' lnc_gsea(tid_cohort = test, t_id = "ENST00000430998", cohort = "BRCA",
#' metric = "logFC", genelist = FALSE,
#'geneset = "./gmt/h.all.v7.0.symbols.gmt",
#'pathway = NULL)
#'
#' @export
#'
lnc_gsea <- function(tid_cohort, cohort, t_id, metric="cor", cor.method = "pearson", genelist = FALSE, geneset=NULL, pathway = NULL)
{
    #tid_cohort <- pre_gsea(cohort, t_id)

    if (metric == "cor") {
        # correlation -----
        res <- NULL
        res <- cor(tid_cohort[,2], tid_cohort[,3:ncol(tid_cohort)],
                   use = 'pairwise.complete.obs', method = cor.method)

        # make res ready for gsea -----
        res <- as.data.frame(t(as.data.frame(res)))
        names(res) <- t_id
        res$genes <- rownames(res)
        res <- res[ ,c(2,1)]
        res<-res[order(-res[,2]),]
        ranks <- tibble::deframe(res)

    } else {
        tid_cohort$group <- ifelse(tid_cohort[[2]] > median(tid_cohort[[2]]), "high", "low")
        # by group, calculate mean for each gene ---
        res <- aggregate(. ~ group, data = tid_cohort[, -c(1:2)], FUN = mean)
        rownames(res) <- res$group
        res$group <- NULL
        resT <- as.data.frame(t(res))

        # log2 FC of high to low for each gene ---
        resT$FC <- resT$high/resT$low
        resT$log2FC <- log2(resT$FC)

        # rownames to genes
        resT$genes <- rownames(resT)
        resT <- resT[ ,c(5,4)]
        resT <-resT[order(-resT[,2]),]
        ranks <- tibble::deframe(resT)
    }

    if (genelist == TRUE){
        ranks.df <- data.frame(gene_name=names(ranks), ranks=ranks)
        write.table(ranks.df,paste0(t_id, "_", cohort, "_", metric, ".orderedgene.txt"),
                    quote=FALSE, col.names = TRUE, row.names = FALSE,sep="\t")
    }
    # Load the pathways into a named list-----
    if (is.null(geneset)){
        geneset <- system.file("extdata", "h.all.v7.0.symbols.gmt", package = "slncGSEA")
    }

    pathways.hallmark <- fgsea::gmtPathways(geneset) # gmt

    fgseaRes <- fgsea::fgsea(pathways=pathways.hallmark, stats=ranks, nperm=1000)

    # tidy the results -----
    fgseaResTidy <- fgseaRes[order(-NES,padj),]
    print(fgseaResTidy)
    data.table::fwrite(fgseaResTidy, paste0(t_id, "_", cohort, "_", metric, ".txt"),
                       col.names = TRUE, row.names = FALSE, sep = "\t", quote = FALSE)


    # gsea plot -----

    if(!is.null(pathway)){
        pdf(file = paste0(pathway, "_", t_id, ".pdf"))
        enrichplot <- fgsea::plotEnrichment(pathways.hallmark[[pathway]], ranks) + ggplot2::labs(title = pathway)
        print(enrichplot)
    }
    if(!is.null(pathway)){

        dev.off()
    }
}

