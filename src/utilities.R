#' Find Variable genes using a negative binomial null model
#' cut.quantile - quantile ceiling on max counts
NB.var.genes <- function(
  object = object, 
  cells.use=NULL, 
  min.cells = 200,
  do.idents=NULL,
  genes.use = NULL, 
  do.plot=TRUE,
  set.var.genes=TRUE,
  x.low.cutoff=0.005, 
  x.high.cutoff=3, 
  diffCV.cutoff=NULL,
  num.sd=NULL, 
  cex.use=0.5,
  cex.text.use=0.5,
  do.spike=FALSE,
  pch.use=16, 
  col.use="black", 
  spike.col.use="red",
  do.ident=FALSE, 
  do.text=TRUE, 
  cut.quantile=0.99,
  rem.mt.rp = FALSE,
  max.cor = 0.5) {
  
  require(MASS)
  print("Identifying variable genes based on UMI Counts. Warning - use this only for UMI based data")
  
  genes.use=set.ifnull(genes.use, rownames(object@data))
  
  if (!do.idents | is.null(do.idents)){
    ident.label = "all"
    cells.use=set.ifnull(cells.use,colnames(object@data))  
    multi.idents = FALSE
  } else {
    if (is.logical(do.idents) & do.idents == T){
      do.idents = levels(object@ident)
    }
    ident.label = do.idents[do.idents %in% levels(object@ident)]
    cells.use = NULL
    if (length(ident.label) >0){ multi.idents = TRUE }
  }

  genes.return = c()
  cells.final = c()
  for (ident in ident.label){
    
    if (multi.idents){ 
      print(paste0("Extracting variable genes for sample : ", ident))
    }
    
    if (is.null(cells.use )){
    cells.use =  WhichCells(object, ident)
  }
    cells.final = c(cells.final, cells.use)
    if (length(cells.use) < min.cells){
      print(paste0("Skipping sample ", ident, " as there are fewer than ", min.cells, " cells"))
      next
    }
    
    count.data=object@raw.data[genes.use,cells.final]
    
    # Empirical mean, var and CV
    mean_emp = Matrix::rowMeans(count.data)
    var_emp = Matrix::rowMeans(count.data^2) - mean_emp^2
    genes.use=names(mean_emp)[mean_emp > 0]
    
    mean_emp = mean_emp[genes.use]
    var_emp = var_emp[genes.use]
    cv_emp = sqrt(var_emp) / mean_emp
    
    # NB sampling
    a=Matrix::colSums(count.data)
    a = a[a <= quantile(a,cut.quantile)]
    size_factor =  a/ mean(a)
    fit=fitdistr(size_factor, "Gamma")
    hist(size_factor, 50, probability=TRUE, xlab="N_UMI/<N_UMI>")
    
    curve(dgamma(x, shape=fit$estimate[1], rate=fit$estimate[2]),from=0, to=quantile(size_factor, 0.99), add=TRUE, col="red",
          main="Gamma dist fit for size factor")
    text(0.8*max(size_factor),0.6, paste("shape = ", round(fit$estimate[1],2)))
    text(0.8*max(size_factor),0.5, paste("rate = ", round(fit$estimate[2],2)))
    
    # Gamma distributions of individual genes are just scaled versions. If X ~ Gamma(a,b)
    # then cX ~ Gamma(a, b/c)
    a_i = rep(fit$estimate[1], length(mean_emp)); names(a_i) = names(mean_emp)
    b_i = fit$estimate[2] / mean_emp; names(b_i) = names(mean_emp)
    mean_NB = a_i / b_i; var_NB = a_i*(1+b_i) / (b_i^2)
    cv_NB = sqrt(var_NB)/mean_NB
    diffCV = log(cv_emp) - log(cv_NB)
    
    hist(diffCV,500, main="Select a delta-logCV cutoff for variable gene: ", xlab="delta-logCV", ylim = c(0,1500), xlim = c(0, quantile(diffCV,0.99)))
    
    if (!is.null(num.sd)){
      diffCV.cutoff = mean(diffCV) + num.sd*sd(diffCV)
    }
    
    if (is.null(diffCV.cutoff)){
      diffCV.cutoff = readline("Select a delta-logCV cutoff (genes with a higher value will be considered):")
      diffCV.cutoff = as.numeric(diffCV.cutoff)
    }
    
    
    print(paste0("Using diffCV = ", round(diffCV.cutoff,2), " as the cutoff"))
    abline(v=diffCV.cutoff, col="red")
    Sys.sleep(3)
    
    print(paste0("Considering only genes with mean counts less than ", x.high.cutoff, " and more than ", x.low.cutoff))
    pass.cutoff=names(diffCV)[which(diffCV > diffCV.cutoff & (mean_emp > x.low.cutoff & mean_emp < x.high.cutoff))]
    print(paste0("Found ", length(pass.cutoff), " variable genes"))
    if (multi.idents){
      genes.return = union(genes.return, pass.cutoff)
      print(paste0("Found ", length(genes.return), " unique genes"))
    } else {
      genes.return = union(genes.return, pass.cutoff)
    }
    if (multi.idents){
      mv.df=data.frame(mean_emp,cv_emp)
      rownames(mv.df)=names(mean_emp)
      mv.df$gene = rownames(mv.df)
      mv.df$ident = ident
      
      if (nrow(object@hvg.info)==0){
        object@hvg.info=mv.df
      } else {
        object@hvg.info = rbind(object@hvg.info, mv.df)
      }
      
    } else {
      
      mv.df=data.frame(mean_emp,cv_emp)
      mv.df$ident = "all"
      rownames(mv.df)=names(mean_emp)
      object@hvg.info=mv.df
    }
    
    if (do.spike) spike.genes=grep("^ERCC", rownames(count.data), value=TRUE)
    if (do.plot) {
      
      plot(mean_emp,cv_emp,pch=pch.use,cex=cex.use,col="black",xlab="Mean Counts",ylab="CV (counts)", log="xy")
      curve(sqrt(1/x), add=TRUE, col="red", log="xy", lty=2, lwd=2)
      or = order(mean_NB)
      lines(mean_NB[or], cv_NB[or], col="magenta", lwd=2)
      points(mean_emp[pass.cutoff], cv_emp[pass.cutoff], col="blue", pch=16, cex=cex.use)
      
      if (do.spike) points(mean_emp[spike.genes],cv_emp[spike.genes],pch=16,cex=cex.use,col=spike.col.use)
      if(do.text) text(mean_emp[pass.cutoff],cv_emp[pass.cutoff],pass.cutoff,cex=cex.text.use)
      
    }  
    cells.use = NULL
    
  }
  
  if (is.null(do.idents) ){
    if (do.ident) {
      identify(mean_emp,cv_emp,labels = names(mean_emp))
    }
  }
  
  if (rem.mt.rp){
    print(paste0("Removing genes that have a correlation greater than ", max.cor," with mt.score or rp.score"))
    cor.vec1 = apply(object@data[genes.return,cells.final],1,function(x) abs(cor(x, object@data.info[cells.final,"mt.score"])))
    cor.vec2 = apply(object@data[genes.return,cells.final],1,function(x) abs(cor(x, object@data.info[cells.final,"rp.score"])))
    var.genes = genes.return[cor.vec1 < max.cor & cor.vec2 < max.cor]
    print(paste0("Removed ", length(genes.return) - length(var.genes), " variable genes"))
    genes.return = var.genes
  }
  
  if (set.var.genes) { 
    object@var.genes=genes.return
    return(object)
  } else {
   return(genes.return)
  }
  
}

set.ifnull = function(a,b){
  if (is.null(a)) return(b)
}

topGOterms = function( fg.genes = NULL,
                       bg.genes = NULL,
                       organism = "Mouse", 
                       ontology.use = "BP",
                       stats.use = "fisher",
                       algorithm.use = "weight01",
                       topnodes.print=20,
                       num.char=100){
  
  if (is.null(fg.genes) | is.null(bg.genes)){
    stop("Error : Both gene lists are empty")
  }
  
  require(topGO)
  if (organism == "Mouse"){
    mapping.use = "org.Mm.eg.db"
    library(org.Mm.eg.db)
  } else if (organism == "Human"){
    mapping.use = "org.Hs.eg.db"
    library(org.Hs.eg.db)
  } else {
    stop("Error : Organisms other than mouse not supported currently")
  }
  
  n = length(bg.genes)
  geneList = integer(n)
  names(geneList) = bg.genes
  geneList[intersect(names(geneList), fg.genes)]=1
  print(paste0("Total ", length(geneList), " genes. ", sum(geneList), " genes in the foreground"))
  geneList = factor(geneList)
  
  if (ontology.use %in% c("BP", "CC", "MF")){
    print(paste0("Using Ontology : ", ontology.use))
  } else {
    stop("Error: Ontology not available. Should be one of BP, CC or MF")
  }
  # Make GO object
  GOdata <- new("topGOdata",
                description = "GOanalysis",
                ontology = ontology.use,
                allGenes = geneList,
                annot = annFUN.org,
                mapping = mapping.use,
                ID = "SYMBOL",
                nodeSize = 10)
  print(paste0("Using the ", stats.use, " statistic with the ", algorithm.use, " algorithm"))
  res.result <- runTest(GOdata, statistic = stats.use, algorithm = algorithm.use)
  to.return = list()
  to.return$GOdata = GOdata
  to.return$res.table <- GenTable(GOdata, pval = res.result, topNodes = topnodes.print, numChar = num.char)
  return(to.return)
}