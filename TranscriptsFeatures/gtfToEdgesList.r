##############################################################
## Conversion of the standard (linear)                      ##
## transcriptional models of genes into exon graphs.        ##
## (c) GNU GPL Vasily V. Grinev, 2016. grinev_vv[at]bsu.by  ##
##############################################################
rm(list = ls())
## Required libraries.
if (!require(GenomicFeatures)){
	source("http://bioconductor.org/biocLite.R")
	biocLite("GenomicFeatures")
}
if (!require(rtracklayer)){
	source("http://bioconductor.org/biocLite.R")
	biocLite("rtracklayer")
}
if (!require(igraph)){
	source("http://bioconductor.org/biocLite.R")
	biocLite("igraph")
}
## Directory(-ies) and file(-s).
gtfDir = "/media/gvv/NGS_Illumina_HiSeq/Files_GTF" #Path to directory with GTF/GFF file(-s).
sgDir = "/media/gvv/NGS_Illumina_HiSeq/SplGraphs" #Path to output directory.
gtf = "Sample SRR1145838, Cufflinks assembled transcripts.gtf" #GTF/GFF file(-s) with annotations.
edgesList = "Sample SRR1145838, list of edges.txt" #Output file with list of edges.
## Converting of the GTF/GFF file into local SQLite database.
txDb = makeTxDbFromGFF(file = paste(gtfDir, gtf, sep = "/"),
					   format = "auto", dataSource = "Kasumi-1 cells", organism = "Homo sapiens",
					   circ_seqs = DEFAULT_CIRC_SEQS, chrominfo = NULL, miRBaseBuild = NA)
saveDb(x = txDb, file = paste(gtfDir, sub("gtf", "sqlite", gtf, ignore.case = TRUE), sep = "/")) #Be careful and indicate correct GTF/GFF file extension in argument "pattern" of sub function.
## Loading of the metadata (from GTF/GFF file) as a data frame object. These data may be used as attributes of vertices and/or edges.
meta = as.data.frame(import(con = paste(gtfDir, gtf, sep = "/"))[, c(6, 7)])[, -1:-5]
meta = meta[!duplicated(meta), ]
meta$FPKM = as.numeric(meta$FPKM) #This is just one example of metadata type.
## Reconstruction of exon graph.
exons = exonsBy(x = txDb, by = c("tx"), use.names = TRUE)
gtfToEdgesList = function(x){
	if (length(x) > 1){
		ex_id = paste(paste(paste(as.character(seqnames(x)@values), ranges(x)@start, sep = ":"),
							ranges(x)@start + ranges(x)@width - 1, sep = "-"),
					  as.character(strand(x)), sep = "_str")
		ed = cbind(ex_id[1:(length(ex_id) - 1)], ex_id[2:length(ex_id)])
	return(ed)
	}
}
edges = lapply(exons, FUN = gtfToEdgesList) #This step may be time-consuming depending from number of processed transcripts, be patient.
edges = edges[lengths(edges) > 0]
## Assigning weights (FPKM) to the edges.
for (i in 1:length(edges)){
	edges[[i]] = cbind(edges[[i]], meta[meta$transcript_id %in% names(edges[i]), ][, 2])
}
edges = do.call(rbind, edges)
edges = as.data.frame(cbind(paste(edges[, 1], edges[, 2], sep = "->"), edges[, 3]), stringsAsFactors = FALSE)
edges$V2 = as.numeric(edges$V2)
edges = aggregate(edges$V2, by = list(edges$V1), FUN = sum)
edges = as.data.frame(cbind(sapply(strsplit(edges$Group.1, split = "->"), "[[", 1),
							sapply(strsplit(edges$Group.1, split = "->"), "[[", 2),
							round(edges$x, digits = 2)),
					  stringsAsFactors = FALSE)
## Saving a list of edges with weights in tab-delimited TXT file.
write.table(edges, file = paste(sgDir, edgesList, sep = "/"), sep = "\t", quote = FALSE, col.names = c("Source_exon", "Sink_exon", "Weight"), row.names = FALSE)
## Conversion of edges list into directed acyclic weighed exon graph (object of class igraph).
splGraph = graph.data.frame(d = edges[, -3], directed = TRUE, vertices = NULL)
E(splGraph)$weight = edges[, 3] #In this case, edges were weighed but any variants are possible.
