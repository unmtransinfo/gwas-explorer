#!/usr/bin/env Rscript
###
# https://stats.stackexchange.com/questions/52756/probability-of-overlap-between-independent-samples-of-different-sizes
# (extreme-tail hypergeometric probability)
###
#options(warn=-1) #suppress warnings
#
library(readr)
library(data.table, quietly=T)
library(plotly, quietly=T)
library(igraph, quietly=T)
#
message(paste(commandArgs(), collapse=" "))
###
Ngenes_min <- 20L #Min genes per disease (TIGA and other source).
Ngenes_max <- 1000L #Max genes per disease (TIGA and other source).
#
###
# EFO graph for subclass association inclusion.
system("gunzip -f data/efo_graph.graphml.gz")
efoG <- read_graph("data/efo_graph.graphml", format="graphml")
message(sprintf("Graph \"%s\": vertices: %d; edges: %d", graph_attr(efoG, "name"), vcount(efoG), ecount(efoG)))
system("gzip -f data/efo_graph.graphml")
#
# Return all subclasses for input efoId.
efoId2Subclasses <- function(G, id_this) {
  if (!(id_this %in% V(G)$efoId)) { return(NULL) }
  v_this <- V(G)[V(G)$efoId == id_this]
  bfs_this <- igraph::bfs(G, v_this, neimode="out", unreachable=F)
  subG <- induced_subgraph(G, bfs_this$order[1:sum(!is.na(bfs_this$order))])
  return(V(subG)$efoId)
}
#
t_start <- Sys.time()
#
###
# JensenLab DISEASES:
#Experiments means (1) DistiLD (GWAS) and (2) COSMIC (somatic mutations in cancer).
diseases_exp <- read_delim(paste0(Sys.getenv("HOME"), "/../data/JensenLab/DISEASES/human_disease_experiments_full.tsv"), "\t", col_names=c("geneEnsp", "geneSymbol", "doId", "doName", "DISEASES_source", "DISEASES_evidence", "DISEASES_confidence"))
setDT(diseases_exp)
diseases_exp <- diseases_exp[order(-DISEASES_confidence), .SD, by=c("doId", "doName")]

###
# Selected DO diseases which map to EFO, in both datasets, and associate with numerous genes:
# Mapping from OxO! https://www.ebi.ac.uk/spot/oxo/
do2efo <- read_delim("data/oxo_doid2efo.tsv", "\t")
setDT(do2efo)
do2efo <- do2efo[distance == 1]
setnames(do2efo, old=c("curie_id", "label", "mapped_curie", "mapped_label"), new=c("doId", "doName", "efoId", "efoName"))
do2efo[, `:=`(mapping_source_prefix=NULL, mapping_target_prefix=NULL, distance=NULL)] #distance all 1
do2efo[, efoId := sub(":", "_", efoId)]

#
tiga <- read_delim("data/gt_stats.tsv.gz", '\t', col_types=cols(.default=col_character(), 
n_study=col_integer(), n_snp=col_integer(), n_snpw=col_double(),
geneNtrait=col_integer(), geneNstudy=col_integer(),
traitNgene=col_integer(), traitNstudy=col_integer(), pvalue_mlog_median=col_double(), or_median=col_double(), study_N_mean=col_double(), rcras=col_double(),
meanRank=col_double(), meanRankScore=col_double()))
setDT(tiga)                                                           
#
tiga <- merge(tiga, do2efo[, .(efoId, doId, doName)], by="efoId")

###
results_diseases <- data.table(
	efoId=rep(as.character(NA), 100),
	efoName=rep(as.character(NA), 100),
	doId=rep(as.character(NA), 100),
	doName=rep(as.character(NA), 100),
	efoSubclassCount=rep(as.character(NA), 100),
	tiga_Ngenes=rep(as.integer(NA), 100),
	diseases_Ngenes=rep(as.integer(NA), 100),
	inCommon_Ngenes=rep(as.integer(NA), 100),
	inCommon_pct=rep(as.integer(NA), 100),
	inCommon_pVal=rep(as.numeric(NA), 100),
	corPearson=rep(as.numeric(NA), 100)
)
i <- 0L
efoIds_all <- c()
efoIds_used_all <- c()
plots_diseases <- list()
cat("i\tefoId\tefoName\tdoId\tdoName\nefoSubclassCount\ttiga_Ngenes\tdiseases_Ngenes\tNgenes_InCommon\tNgenes_InCommonPct\tNgenes_InCommonPval\n")
for (efoId_this in tiga[, unique(efoId)]) {
  efoIds_this <- efoId2Subclasses(efoG, efoId_this)
  if (is.null(efoIds_this)) {
    message(sprintf("ERROR: not found in efoGraph: %s", efoId_this))
    next
  }
  #message(sprintf("Subclasses %s: %d", efoId_this, length(efoIds_this)-1))
  if (length(efoIds_this)>999) {
    message(sprintf("Too many subclasses; skipping: %s", efoId_this))
    next
  }
  efoIds_all <- c(efoIds_all , efoIds_this)
  if (!inrange(tiga[efoId %in% efoIds_this, uniqueN(ensemblId)], Ngenes_min, Ngenes_max)) { next }
  tiga_this <- tiga[efoId %in% efoIds_this]
  doIds_this <- tiga_this[, doId]
  if (!inrange(diseases_exp[doId %in% doIds_this, uniqueN(geneSymbol)], Ngenes_min, Ngenes_max)) { next }
  efoIds_used_all <- c(efoIds_used_all , efoIds_this)
  
  i <- i + 1L
  efoName_this <- tiga[efoId==efoId_this, first(trait)]
  doId_this <- tiga[efoId==efoId_this, first(doId)]
  doName_this <- tiga[efoId==efoId_this, first(doName)]
  tiga_Ngenes <- tiga_this[, uniqueN(ensemblId)]
  diseases_exp_this <- diseases_exp[doId %in% doIds_this]
  diseases_Ngenes <- diseases_exp_this[, uniqueN(geneSymbol)]
  genes_in_common <- intersect(diseases_exp_this$geneSymbol, tiga_this$geneSymbol)

  inCommon_pval <- phyper(length(genes_in_common), 
	min(tiga_Ngenes, diseases_Ngenes),
	20000-min(tiga_Ngenes, diseases_Ngenes),
	max(tiga_Ngenes, diseases_Ngenes),
	lower.tail=F)

  # Correlate scores
  tiga_this_scores <- tiga_this[, .(efoId, doId, ensemblId, geneSymbol, meanRankScore)]
  diseases_exp_this_scores <- diseases_exp_this[, .(doId, geneSymbol, DISEASES_confidence)]
  tiga_vs_diseases <- merge(tiga_this_scores, diseases_exp_this_scores, by=c("doId", "geneSymbol"), all=F)
  if (length(genes_in_common) > 2) {
    corPearson <- cor(tiga_vs_diseases$meanRankScore, tiga_vs_diseases$DISEASES_confidence, method="pearson")
  } else {
    corPearson <- NA
  }

  cat(sprintf("%d\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%.1f%%\t%g\t%.3f\n", i, efoId_this, efoName_this, doId_this, doName_this, length(efoIds_this)-1, tiga_Ngenes, diseases_Ngenes, length(genes_in_common), inCommon_pval, 100*length(genes_in_common)/min(diseases_Ngenes, tiga_Ngenes), corPearson))
  if (i>nrow(results_diseases)) {
    dtcopy <- results_diseases
    dtcopy[, names(dtcopy) := NA]
    results_diseases <- rbindlist(list(results_diseases, dtcopy))
  }
  set(results_diseases, i, names(results_diseases), list(efoId_this, efoName_this, doId_this, doName_this, length(efoIds_this)-1, tiga_Ngenes, diseases_Ngenes, length(genes_in_common), 100*length(genes_in_common)/min(diseases_Ngenes, tiga_Ngenes), inCommon_pval, corPearson))
  
  annos <- c(sprintf("corPearson: %.3f", corPearson), sprintf("Subclasses: %d", length(efoIds_this)-1))
  plots_diseases[[i]] <- plot_ly(tiga_vs_diseases, x=~DISEASES_confidence, y=~meanRankScore, type="scatter", mode="markers") %>%
	layout(title=sprintf("%s (%s)<br>meanRankScore vs DISEASES_confidence", efoId_this, efoName_this)) %>%
	add_annotations(text=annos, showarrow=F, x=.5, y=.1, xref="paper", yref="paper")
  
}
setorder(results_diseases, -tiga_Ngenes, na.last=T)
results_diseases <- results_diseases[!is.na(efoId)]
write_delim(results_diseases, "data/benchmarks_results_diseases.tsv", "\t")
message(sprintf("efoIds_all: %d; efoIds_used_all: %d", length(efoIds_all), length(efoIds_used_all)))
write_delim(data.table(efoId=unique(efoIds_used_all)), "data/benchmarks.efoId", col_names=F)
#
###
# Totals:
message(sprintf("TOTAL efoIds: %d; doIds: %d; TIGA_Ngenes: %d; DISEASES_Ngenes: %d; InCommon: %d (median %.1f%%); InCommonPval (median): %g; corPearson: %.3f\n",
                results_diseases[, uniqueN(efoId)],
                results_diseases[, uniqueN(doId)],
	results_diseases[, sum(tiga_Ngenes)],
	results_diseases[, sum(diseases_Ngenes)],
	results_diseases[, sum(inCommon_Ngenes)],
	results_diseases[, median(inCommon_pct, na.rm=T)],
	results_diseases[, median(inCommon_pVal, na.rm=T)],
	results_diseases[, median(corPearson, na.rm=T)]))
#
#
#stop("DEBUG")
###
# OpenTargets (via OpenTargets API)
if (system("uname -s", intern=T) == "Darwin") {
  PYTHONEXE <- "/usr/local/opt/python@3.8/bin/python3"
} else {
  PYTHONEXE <- "python3"
}
cmd <- sprintf("%s -m BioClients.opentargets.Client searchAssociations -v --idtype 'disease' --i data/benchmarks.efoId --o data/benchmarks_opentargets.tsv", PYTHONEXE)
message(cmd)
system(cmd)
system("gzip -f data/benchmarks_opentargets.tsv")
#
# id, is_direct, target_id, gene_name, gene_symbol, disease_id, disease_efo_label, score_overall
opentargets <- read_delim("data/benchmarks_opentargets.tsv.gz", "\t")
setDT(opentargets)

for (name in names(opentargets)) {
  if ((grepl("^assn_score_.*\\.", name) | grepl("^evidence_count_.*\\.", name)) & !grepl("\\.ot_genetics_portal$", name)) {
    opentargets[[name]] <- NULL
  }
}
opentargets <- opentargets[assn_score_source.ot_genetics_portal>0.0 & evidence_count_source.ot_genetics_portal>0.0]
opentargets[, `:=`(id=NULL, is_direct=NULL)]
setnames(opentargets, old=c("target_id", "gene_name", "gene_symbol", "disease_id", "disease_efo_label", "score_overall"), new=c("ensgId", "geneName", "geneSymbol", "efoId", "efoName", "otOverallScore"))

###
results_ot <- data.table(
	efoId=rep(as.character(NA), 100),
	efoName=rep(as.character(NA)),
	doId=rep(as.character(NA), 100),
	doName=rep(as.character(NA), 100),
	efoSubclassCount=rep(as.character(NA), 100),
	tiga_Ngenes=rep(as.integer(NA), 100),
	ot_Ngenes=rep(as.integer(NA), 100),
	inCommon_Ngenes=rep(as.integer(NA), 100),
	inCommon_pct=rep(as.integer(NA), 100),
	inCommon_pVal=rep(as.numeric(NA), 100),
	corPearson=rep(as.numeric(NA), 100)
)
i <- 0L
plots_opentargets <- list()
cat("i\tefoId\tefoName\tdoId\tdoName\tefoSubclassCount\ttiga_Ngenes\topentargets_Ngenes\tNgenes_InCommon\tNgenes_InCommonPct\tNgenes_InCommonPval\tcorPearson\n")
for (efoId_this in tiga[, unique(efoId)]) {
  efoIds_this <- efoId2Subclasses(efoG, efoId_this)
  if (is.null(efoIds_this)) {
    message(sprintf("ERROR: not found in efoGraph: %s", efoId_this))
    next
  }
  #message(sprintf("Subclasses %s: %d", efoId_this, length(efoIds_this)-1))
  if (length(efoIds_this)>999) {
    message(sprintf("Too many subclasses; skipping: %s", efoId_this))
    next
  }
  if (efoId_this == "EFO_0004247") { } #no-op "mood disorder"
  else if (!inrange(tiga[efoId %in% efoIds_this, uniqueN(ensemblId)], Ngenes_min, Ngenes_max)) { next }
  else if (!inrange(opentargets[efoId %in% efoIds_this, uniqueN(geneSymbol)], Ngenes_min, Ngenes_max)) { next }
  
  tiga_this <- tiga[efoId %in% efoIds_this]
  
  i <- i + 1L
  efoName_this <- tiga[efoId==efoId_this, first(trait)]
  doId_this <- tiga[efoId==efoId_this, first(doId)]
  doName_this <- tiga[efoId==efoId_this, first(doName)]

  tiga_Ngenes <- tiga_this[, uniqueN(ensemblId)]
  opentargets_this <- opentargets[efoId %in% efoIds_this]
  opentargets_this <- opentargets_this[assn_score_source.ot_genetics_portal>=.8]
  opentargets_Ngenes <- opentargets_this[, uniqueN(geneSymbol)]
  genes_in_common <- intersect(opentargets_this$geneSymbol, tiga_this$geneSymbol)

  inCommon_pval <- phyper(length(genes_in_common), 
	min(tiga_Ngenes, opentargets_Ngenes),
	20000-min(tiga_Ngenes, opentargets_Ngenes),
	max(tiga_Ngenes, opentargets_Ngenes),
	lower.tail=F)

  # Correlate scores
  tiga_this_scores <- tiga_this[, .(efoId, doId, ensemblId, geneSymbol, meanRankScore)]
  opentargets_this_scores <- opentargets_this[, .(efoId, geneSymbol, otOverallScore)]
  tiga_vs_opentargets <- merge(tiga_this_scores, opentargets_this_scores, by=c("efoId", "geneSymbol"), all=F)
  if (length(genes_in_common) > 2) {
    corPearson <- cor(tiga_vs_opentargets$meanRankScore, tiga_vs_opentargets$otOverallScore, method="pearson")
  } else {
    corPearson <- NA
  }

  cat(sprintf("%d\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%.1f%%\t%g\t%.3f\n", i, efoId_this, efoName_this, doId_this, doName_this, length(efoIds_this)-1, tiga_Ngenes, opentargets_Ngenes, length(genes_in_common), 100*length(genes_in_common)/min(opentargets_Ngenes, tiga_Ngenes), inCommon_pval, corPearson))
  if (i>nrow(results_ot)) {
    dtcopy <- results_ot
    dtcopy[, names(dtcopy) := NA]
    results_ot <- rbindlist(list(results_ot, dtcopy))
  }
  set(results_ot, i, names(results_ot), list(efoId_this, efoName_this, doId_this, doName_this, length(efoIds_this)-1, tiga_Ngenes, opentargets_Ngenes, length(genes_in_common), 100*length(genes_in_common)/min(opentargets_Ngenes, tiga_Ngenes), inCommon_pval, corPearson))
  annos <- c(sprintf("corPearson: %.3f", corPearson), sprintf("Subclasses: %s", paste(collapse="; ", efoIds_this)))
  plots_opentargets[[i]] <- plot_ly(tiga_vs_opentargets, x=~otOverallScore, y=~meanRankScore, type="scatter", mode="markers") %>%
	layout(title=sprintf("%s (%s)<br>meanRankScore vs otOverallScore", efoId_this, efoName_this)) %>%
	add_annotations(text=annos, showarrow=F, x=.5, y=.1, xref="paper", yref="paper")
  
}
setorder(results_ot, -tiga_Ngenes, na.last=T)
results_ot <- results_ot[!is.na(efoId)]
write_delim(results_ot, "data/benchmarks_results_opentargets.tsv", "\t")
#
###
# Totals:
message(sprintf("TOTAL efoIds: %d; TIGA_Ngenes: %d; OPENTARGETS_Ngenes: %d; InCommon: %d (median %.1f%%); InCommonPval (median): %g; corPearson: %.3f\n",
	results_diseases[, uniqueN(efoId)],
	results_ot[, sum(tiga_Ngenes)],
	results_ot[, sum(ot_Ngenes)],
	results_ot[, sum(inCommon_Ngenes)],
	results_ot[, median(inCommon_pct, na.rm=T)],
	results_ot[, median(inCommon_pVal, na.rm=T)],
	results_diseases[, median(corPearson, na.rm=T)]))
#
t_elapsed <- (Sys.time()-t_start)
message(sprintf("Elapsed time: %.2f %s", t_elapsed, attr(t_elapsed, "units")))
#
