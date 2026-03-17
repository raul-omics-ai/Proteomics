########## 19/02/2026 ##########

# ================================================================ #
# ========== AUTOMATIC DOWNSTREAM ANALYSIS FOR PROTEOMIC DATA ====
# ================================================================ #
#'
#' This function performs a complete and automated downstream analysis workflow
#' for label-free quantitative (LFQ) proteomics data. It includes data loading,
#' quality control (QC), filtering, missing value imputation, normalization,
#' statistical testing, and visualization of differential protein abundance.
#'
#' The pipeline is primarily based on the \code{DEP} package and generates
#' multiple plots and an Excel report summarizing all intermediate and final results.
#'
#' @param ms2_file_path Character. Path to the MS2 (evidence) file.
#' @param peptide_file_path Character. Path to the peptide-level file.
#' @param proteinGroup_file_path Character. Path to the proteinGroups file.
#' @param metadata Data frame. Experimental design table containing at least
#' the following columns: \code{label}, \code{condition}, and \code{replicate}.
#' @param where_to_save Character or NULL. Directory where output files will be saved.
#' If NULL, the current working directory is used.
#' @param title Character. Name used to create the output directory and label results.
#' @param level Character. Level of analysis ("protein" or "peptide"). Currently
#' optimized for protein-level analysis.
#' @param filtering Character. Missing value filtering strategy. Options are:
#' \code{"stringent"} (default) or \code{"relaxed"}.
#' @param alpha Numeric. Significance threshold for adjusted p-values in differential
#' analysis (default = 0.05).
#' @param lfc Numeric. Log2 fold-change threshold for differential abundance
#' (default = 1).
#'
#' @details
#' The workflow includes the following steps:
#' \enumerate{
#'   \item Loading required packages and custom helper functions.
#'   \item Reading proteomics input files (MS2, peptides, proteinGroups).
#'   \item Initial quality control and summary statistics.
#'   \item Removal of decoy and contaminant entries.
#'   \item Handling duplicated protein identifiers.
#'   \item Construction of a \code{SummarizedExperiment} object.
#'   \item Visualization of protein identification metrics.
#'   \item Filtering based on missing values.
#'   \item Missing value imputation (user-defined method).
#'   \item Data normalization using variance stabilizing normalization (VSN).
#'   \item Sample-level quality control (correlation heatmap, PCA).
#'   \item Differential abundance analysis using linear modeling.
#'   \item Generation of multiple plots (QC, PCA, heatmaps, volcano plots).
#'   \item Export of results and intermediate data to an Excel report.
#' }
#'
#' The function also saves all plots as image files and organizes outputs into
#' structured directories.
#'
#' @return
#' This function does not return an R object. Instead, it generates:
#' \itemize{
#'   \item An output directory containing all plots.
#'   \item An Excel file (\code{DE_Report.xlsx}) with QC metrics and differential analysis results.
#'   \item Intermediate processed datasets (filtered, imputed, normalized).
#' }
#'
#' @note
#' The function requires user interaction to select the missing value imputation
#' method via console input.
#'
#' @import DEP ggplot2 dplyr tidyr SummarizedExperiment
#' @importFrom readr read_tsv
#' @importFrom openxlsx createWorkbook addWorksheet writeDataTable saveWorkbook
#'
#' @examples
#' \dontrun{
#' auto_proteomic_analysis(
#'   ms2_file_path = "evidence.txt",
#'   peptide_file_path = "peptides.txt",
#'   proteinGroup_file_path = "proteinGroups.txt",
#'   metadata = metadata_df,
#'   where_to_save = "results/",
#'   title = "My_Proteomics_Run"
#' )
#' }
#'
#' @export

auto_proteomic_analysis <- function(ms2_file_path, 
                                    peptide_file_path,
                                    proteinGroup_file_path,
                                    metadata,
                                    where_to_save = NULL,
                                    title = "Proteomic_Analysis",
                                    level = "protein",
                                    filtering = "stringent",
                                    alpha = 0.05, lfc = 1
                                    ){
  # ======================================================================== #
  # ==== BLOCK 0: Loading packages and setting up the working directory ==== 
  # ======================================================================== #
  # loading custom functions
  source("~/Documentos/09_scripts_R/print_centered_note_v1.R")
  source("~/Documentos/09_scripts_R/Automate_Saving_ggplots.R")
  source("~/Documentos/09_scripts_R/automate_saving_dataframes_xlsx_format.R")
  source("~/Documentos/09_scripts_R/create_sequential_dir.R")
  source("~/Documentos/09_scripts_R/generate_condition_colors.R")
  
  print_centered_note(toupper("Initializing Function"))
  print("Loading packages")
  
  # loading packages
  list.of.packages = c("readr", "DEP", "ggplot2", "SummarizedExperiment", "dplyr", "patchwork", 
                       "tidyr", "gridExtra", "stringr", "pheatmap", "openxlsx", "RColorBrewer",
                       "stringr")
  
  new.packages = list.of.packages[!(list.of.packages %in% installed.packages())]
  if(length(new.packages) > 0) install.packages(new.packages)
  
  invisible(lapply(list.of.packages, FUN = library, character.only = T))
  rm(list.of.packages, new.packages)

  # Checkpoints
  print("Checking checkpoints")
  # 1. Create Workbook
  wb <- createWorkbook()
  
  # 2.Are the mandatory columns in the metadata dataset?
  if(!all(c("label", "condition", "replicate") %in% colnames(metadata))){
    stop("Please, check if the metadata dataset has the 3 mandatory colnames: label, condition and replicate")
  }
  
  # creating output directory
  print("Setting up working directory")
  where_to_save <- ifelse(is.null(where_to_save), getwd(), where_to_save)
  output_dir <- create_sequential_dir(path = where_to_save, name = title)
  
  # creating the folder for individual plots
  print("Creating subfolders")
  individual_plots_dir <- create_sequential_dir(path = output_dir, name = "Individual_Plots")
  
  # ========================================== #
  # ==== BLOCK 1: LOADING PROTEOMIC FILES ==== 
  # ========================================== #
  print_centered_note(toupper("Reading files"))
  
  # ms2 level
  print("Reading Evidence File")
  evidence <- read.table(ms2_file_path, sep = "\t", header = T)
  
  # peptide level
  print("Reading Peptide File")
  peptides <- read.table(peptide_file_path, sep = "\t", header = T)
  
  # protein level
  print("Reading Protein File")
  proteinGroups <- read.table(proteinGroup_file_path, sep = "\t", header = T)
  
  # ===================================== #
  # ==== BLOCK 2: INITIAL QC METRICS ====
  # ===================================== #
  print_centered_note(toupper("Initial Quality Control"))
  
  # Initial Number of ms2 spectra, peptides and proteins
  total_proteins <- nrow(proteinGroups) # proteins
  num_identificaciones <- nrow(evidence) # ms2 spectra
  num_peptides <- evidence %>% 
    distinct(Sequence) %>% 
    nrow() # peptides
  
  # initial summary
  initial_summary <- data.frame("MS2" = num_identificaciones,
                                     "Peptides" = num_peptides,
                                     "Proteins" = total_proteins) %>%
    pivot_longer(cols = everything(), names_to = "Level", values_to = "Count") %>%
    as.data.frame()
  
  # =========================================================== #
  # ==== BLOCK 3: FILTERING DECOY AND CONTAMINANT FEATURES ====
  # =========================================================== #
  print_centered_note(toupper("Filtering Decoys and Contaminant Proteins"))
  
  # ms2 level
  clean_espectra_df <- dplyr::filter(evidence, 
                                  Reverse != "+",  # Para eliminar las proteínas decoy
                                  Potential.contaminant != "+"# Para eliminar proteínas contaminates
  )
  
  num_clean_spec <- nrow(clean_espectra_df)
  
  # peptide level
  clean_peptides_df <- dplyr::filter(peptides, 
                                  Reverse != "+",  # Para eliminar las proteínas decoy
                                  Potential.contaminant != "+"# Para eliminar proteínas contaminates
  )
  
  num_clean_pept <- nrow(clean_peptides_df)
  
  #protein level
  clean_proteomic_df <- dplyr::filter(proteinGroups, 
                                   Reverse != "+",  # Para eliminar las proteínas decoy
                                   Potential.contaminant != "+"# Para eliminar proteínas contaminates
  )
  num_clean_proteins <- nrow(clean_proteomic_df)
  
  # post filtering summary
  postqc_summary <- data.frame("MS2" = num_clean_spec,
                                "Peptides" = num_clean_pept,
                                "Proteins" = num_clean_proteins) %>%
    pivot_longer(cols = everything(), names_to = "Level", values_to = "Count") %>%
    as.data.frame()
  
  # Summary visualiztions
  initial_summary$Filtering <- "Pre-Filter"
  postqc_summary$Filtering <- "Post-Filter"
  
  filtering_report_df <- rbind(initial_summary, postqc_summary)
  filtering_report_df$Filtering <- factor(filtering_report_df$Filtering,
                                          levels = c("Pre-Filter", "Post-Filter"))
  
  print("Saving Filtering Report")
  addWorksheet(wb, "Initial Summary")
  writeDataTable(wb, sheet = "Initial Summary", x = filtering_report_df)
  
  p <- ggplot(filtering_report_df, aes(x = Filtering, y = Count, fill = Filtering)) +
    geom_bar(stat="identity") +
    facet_wrap(.~Level, scales = "free") + 
    theme(legend.position = "none")+ 
    scale_fill_manual(breaks = c("Pre-Filter", "Post-Filter"), 
                      values=c("#c33149", "#f5b841"))+
    theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1))+
    geom_text(aes(label=Count), vjust=1.6, color="white", size=3.5)+
    xlab(NULL)+
    ggtitle(label = "Total Amount of Features")+
    theme(plot.title = element_text(face = "bold"))
  
  save_ggplot(p, title = "QC_Features", folder = individual_plots_dir, width = 3000, height = 2000)
  
  # ======================================== #
  # ==== BLOCK 4: DUPLICATES MANAGEMENT ====
  # ======================================== #
  # Esta parte es a nivel de proteinGroup, entonces más adelante cuando termine la parte de peptide
  # group haré un if statement para poder controlar a qué nivel quiero el análisis
  # if(level = "protein"){} # Key for protein level analysis
  # if(level = "peptide"){} # Key for peptide level analysis
  
  # Check duplicates
  if(clean_proteomic_df$Gene.names %>% duplicated() %>% any()){
    print_centered_note(toupper("Removing duplicates"))
    
    # Make a table with duplicated names
    duplicated_freq_table <- clean_proteomic_df %>% group_by(Gene.names) %>% summarize(frequency = n()) %>% 
      arrange(desc(frequency)) %>% filter(frequency > 1) %>%
      as.data.frame()
    
    print("Saving Duplicate Frequency Table")
    addWorksheet(wb, "Dup Frequency Table")
    writeDataTable(wb, sheet = "Dup Frequency Table", x = duplicated_freq_table)
    
    # Make unique names using the annotation in the "Gene.names" column as primary names and the annotation in "Protein.IDs" as name for those that do not have an gene name.
    proteomic_data<- make_unique(clean_proteomic_df, "Gene.names", "Protein.IDs", delim = ";")
  } else{
    proteomic_data <- clean_proteomic_df
  }# else if key for duplicates
  
  # =================================== #
  # ==== BLOCK 5: CREATE SE OBJECT ====
  # =================================== #
  print_centered_note(toupper("Creating SummarizeExperiment Object"))
  
  # Exctact the intensities from LFQ column
  LFQ_columns <- grep("LFQ.", colnames(proteomic_data)) # get LFQ column numbers
  
  # Check if metadata has the column names correctly
  # metadata must have 3 colums: label, condition and replicate
  
  # Second check: Metadata label rows must match with colnames of LFQ intensity
  # Remove LFQ.intensity. label
  print("Matching protein colnames with rownames of metadata")
  intensity_sample_order <- str_remove(pattern = "LFQ.intensity.", string = colnames(proteomic_data)[LFQ_columns])
  
  if(!all(metadata$label == intensity_sample_order)){
    stop("Please check if samples rownames in metadata match with intensity colnames in proteomic data")
  }
  
  # create SE object
  data_se <- make_se(proteomic_data, LFQ_columns, metadata)
  
  # ==== GLOBAL COLOR SETUP FOR THE WHOLE PIPELINE ====== #
  print("Setting up color pallete")
  # Extraer condiciones del SE o metadata
  conditions <- metadata$condition
  
  # Crear paleta global para todo el pipeline
  condition_colors <- generate_condition_colors(
    conditions
  )
  
  # Esto permite usar tanto fill como color en ggplot
  color_scale_fill  <- scale_fill_manual(values = condition_colors)
  color_scale_color <- scale_color_manual(values = condition_colors)
  
  # Initial Visualizations
  print("Creating some visualizations")
  # 1.Protein per sample
  proteins_per_sample <- plot_numbers(data_se) + 
    geom_text(aes(label=sum), vjust=1.6, color="white", size=3.5) +
    ggtitle(label = "Proteins per sample") +
    color_scale_fill
    
  save_ggplot(plot = proteins_per_sample, title = "Proteins_Per_Sample", 
              folder = individual_plots_dir, width = 3000, height = 2000)
  # 2. Proteins per group
  proteins_per_group <- plot_numbers(data_se, plot = F) %>%
    group_by(condition) %>% summarise(total_proteins = sum(proteins_in_sample),
                                      n_samples = n()) %>%
    mutate("label" = paste0("(",n_samples, "/", nrow(metadata), ")")) %>%
    ggplot(aes(x = condition, y = total_proteins, fill = condition))+
    geom_col() + 
    color_scale_fill +
    geom_text(aes(label=label), vjust=1.6, color = "white",
              fontface = "bold",
              size = 3.5)+
    labs(title = "Sum of Proteins per Condition", x = "", y = "Number of proteins", 
         subtitle = "Number of samples in each group in brackets") + 
    theme_DEP2()+
    theme(legend.position = "none")
  
  save_ggplot(plot = proteins_per_group, title = "Sum_Proteins_Per_Group", 
              folder = individual_plots_dir, width = 3000, height = 2000)
  # 3. Coverage
  coverage_plot <- plot_coverage(data_se) + 
    scale_fill_brewer(palette = "Paired") +  
    geom_text(aes(label = Freq),
              position = position_stack(vjust = 0.5),
              color = "black", size = 3) 
  
  save_ggplot(plot = coverage_plot, title = "Coverage_Plot", 
              folder = individual_plots_dir, width = 2000, height = 2000)
  
  # ================================= #
  # ==== BLOCK 6: MISSING VALUES ====
  # ================================= #
  print_centered_note(toupper("Managing Missing Values"))
  
  # 1. Distribution of missing values
  mv_barplot <- plot_frequency(data_se)
  save_ggplot(plot = mv_barplot, title = "Protein_identification_by_samples", 
              folder = individual_plots_dir, width = 3000, height = 2000)
  
  # 2. Filtering proteins with high percent of missing values
  print("Filtering Missing Values")
  if(filtering == "stringent"){
    print("Stringent filter were selected to remove missing values")
    # Filter for proteins that are identified in all replicates of at least one condition
    data_filt <- filter_missval(data_se, thr = 0)
  } #if key for stringent filtering
  
  if(filtering == "relaxed"){
    print("Relaxed filter were selected to remove missing values")
    # Less stringent filtering:
    # Filter for proteins that are identified in 2 out of 3 replicates of at least one condition
    data_filt <- filter_missval(data_se, thr = 1)
  } # if key for relaxed filtering
  
  # 3.Visualization of filtering
  print("Creating some visualizations")
  proteins_per_sample_after_filtering_mv <- plot_numbers(data_filt) + 
    geom_text(aes(label=sum), vjust=1.6, color="white", size=3.5) +
    color_scale_fill +
    ggtitle(label = "Proteins per sample after Missing Value Filtering", subtitle = paste0(str_to_title(filtering), " filter"))
  
  save_ggplot(proteins_per_sample_after_filtering_mv, title = "Proteins_per_sample_after_MV_filter",
              folder = individual_plots_dir, width = 3000, height = 2000)
  
  
  # Summary of filtering
  print("Saving Summary Filtering Report")
  summary_filtering_df <- data.frame("# proteins pre MV filtering: " = nrow(data_se@assays@data@listData[[1]]),
                                     "# proteins post MV filtering: " = nrow(data_filt@assays@data@listData[[1]]),
                                     "# proteins removed: " = nrow(data_se@assays@data@listData[[1]]) - nrow(data_filt@assays@data@listData[[1]]),
                                     check.names = FALSE)
  
  addWorksheet(wb, "Summary_Filtering")
  writeDataTable(wb, sheet = "Summary_Filtering", x = summary_filtering_df)
  
  addWorksheet(wb, "log2Int_Filtered")
  writeDataTable(wb, sheet = "log2Int_Filtered", x = assays(data_filt) %>% 
                   data.frame() %>% 
                   tibble::rownames_to_column(var = "name")
  )
  
  # Cobertura
  post_mvcoverage_plot <- plot_coverage(data_filt) + 
    scale_fill_brewer(palette = "Paired") +  
    geom_text(aes(label = Freq),
              position = position_stack(vjust = 0.5),
              color = "black", size = 3) +
    ggtitle("Protein coverage after Missing Value Filtering")

  save_ggplot(plot = post_mvcoverage_plot, title = "Protein_Coverage_Post_MV_Filtering", 
              folder = individual_plots_dir, width = 2000, height = 2000)
  
  # QC Visualization Figure
  print("Creating QC Figure")
  qc_figure <- (p / mv_barplot) | (proteins_per_sample + coverage_plot) / (proteins_per_sample_after_filtering_mv + post_mvcoverage_plot)
  
  qc_figure <- qc_figure + 
    theme(plot.tag = element_text(face = "bold")) &
    plot_annotation(
      tag_levels = "A", 
      theme = theme(legend.position = "none"))
  
  save_ggplot(qc_figure, title = "Protein_Quality_Control", width = 10000, height = 6000, 
              folder = output_dir, dpi = 300)
  
  # 4.Missing Value Imputation
  print("Saving Missing Value Heatmap")
  Missing_value_heatmap <- plot_missval(data_filt)
  
  png(filename = file.path(output_dir, "03_Missing_Value_Heatmap.png"), 
      width = 3000, height = 2000, res = 300)
  print(Missing_value_heatmap)
  dev.off()
  
  # 5.Select the Missing Value Strategy
  message("Rule of thumb: The MNARs fall on the left side (QRILC)")
  message("Imputation methods available in DEP: \nbpca, knn, QRILC, MLE, MinDet, \nMinProb, man, min, zero, mixed, nbavg")
  
  imp_method <- readline(prompt = "Choose a imputation method: ")
  print_centered_note(toupper("Imputing Missing Values"))
  print(paste0("Selected method: ", imp_method))
  data_imp <- impute(data_filt, fun = imp_method)
  
  print("Saving Imputed Dataset")
  addWorksheet(wb, "log2Int_Imp")
  writeDataTable(wb, sheet = "log2Int_Imp", x = assays(data_imp) %>% 
                   data.frame() %>% 
                   tibble::rownames_to_column(var = "name")
  )
  
  # Plot intensity distributions and cumulative fraction of proteins with and without missing values
  print("Creating some visualizations")
  intensity_distribution_mv <- plot_detect(data_filt)
  save_ggplot(intensity_distribution_mv, title = "Intensity_Of_Proteins_with_MV", 
              folder = individual_plots_dir,
              width = 3000, height = 2000)
  
  # Visualization of imputation
  density_imputation <- plot_imputation(data_filt, data_imp) +
    ggtitle(label = "Density Plot before and after Imputation",
            subtitle = "The distributions of both graphs should look similar.")+
    color_scale_color

  save_ggplot(density_imputation, title = "Density_Plot_Imputation", 
              folder = individual_plots_dir,
              width = 3000, height = 2000)
  
  # ================================ #
  # ==== BLOCK 7: NORMALIZATION ====
  # ================================ #
  print_centered_note(toupper("Normalizing Intensities Value"))
  # 1.Normalization
  # Normalize the data with vsn transformation
  data_norm <- normalize_vsn(data_imp)
  
  print("Saving Normalized Dataset")
  addWorksheet(wb, "log2Int_Normalized")
  writeDataTable(wb, sheet = "log2Int_Normalized", x = assays(data_norm) %>% 
                   data.frame() %>% 
                   tibble::rownames_to_column(var = "name")
  )
  # 2.Visualize normalization 
  # by boxplots for all samples before and after normalization
  print("Creating some visualizations")
  normalization_plot <- plot_normalization(data_imp, data_norm) + 
    ggtitle("Effect of vst Normalization") + 
    color_scale_fill
  save_ggplot(normalization_plot, title = "Normalization_Plot", folder = individual_plots_dir,
              width = 3000, height = 2000)
  
  mds_plot <- meanSdPlot(data_norm) 
  save_ggplot(mds_plot$gg, title = "MeanSdPlot", folder = individual_plots_dir,
              width = 3000, height = 2000)
  
  # Imputation and Normalization Figure
  print("Creating Normalizations and Imputation Figure")
  imput_norm_figure <- ( ggplotify::as.ggplot(intensity_distribution_mv) / density_imputation ) | (normalization_plot / mds_plot$gg)
  
  imput_norm_figure <- imput_norm_figure + plot_annotation(tag_levels = "A", 
                                                           title = "Effect of Imputation and Normalization",
                                                           theme = theme(title=element_text(size = 20, family = "bold", hjust = 0.5),
                                                                         plot.tag = element_text(face = "bold")))
  
  save_ggplot(imput_norm_figure, title = "Effect_Of_Imputation_And_Normalization", 
              folder = output_dir,
              width = 4000, height = 3000)
  
  # ================================== #
  # ==== BLOCK 8: SAMPLE-LEVEL QC ====
  # ================================== #
  print_centered_note(toupper("Sample-Level Quality Control "))
  
  # 1. Correlation Heatmap
  cor_matrix <- plot_cor(data_norm, 
                         significant = F, 
                         lower = 0, 
                         upper = 1, 
                         pal = "GnBu",
                         #indicate = c("condition", "replicate"), 
                         plot = F)
  
  # Add annotation as described above, and change the name of annotation
  # Nota para el futuro: Poner en el script un código de colores que siempre sea el mismo para todos
  # los grupos experimentales porque en este gráfico se cambian los colores al revés
  print("Creating some visualizations")
  
  # Heatmap
  ann_colors <- list(condition = condition_colors)
  pheatmap_annotation <- as.data.frame(colData(data_norm)["condition"])
  cor_heatmap <- pheatmap(
    cor_matrix,
    annotation_col    = pheatmap_annotation,
    annotation_colors = ann_colors,
    main = "Sample-Level Correlation Heatmap", 
    silent = TRUE
  )
  
  cor_heatmap <- ggplotify::as.ggplot(cor_heatmap$gtable)
  save_ggplot(plot = cor_heatmap, title = "Sample_Level_Correlation_Heatmap", 
              folder = individual_plots_dir,
              height = 2000, width = 3000)
  # 2.PCA
  p.pca <- plot_pca(data_norm, x = 1, y = 2, 
                    n = nrow(data_norm@assays), # use all detected proteins
                    point_size = 4, label=TRUE,
                    indicate = "condition") + 
    color_scale_color
  
  save_ggplot(plot = p.pca, title = "Sample_Level_PCA", folder = individual_plots_dir,
              height = 2000, width = 3000)
  
  # ================================================== #
  # ==== BLOCK 9: DIFFERENTIAL ABUNDANCE ANALYSIS ====
  # ================================================== #
  print_centered_note(toupper("Performing Differential Abundance Analysis "))
  
  # 1.Fitting Model
  print("Fitting the model")
  data_diff_all_contrasts <- test_diff(data_norm, type = "all")
  de_proteins <- add_rejections(data_diff_all_contrasts, alpha = alpha, lfc = lfc)
  
  # table(rowData(de_proteins)$significant)
  print("Saving the results")
  data_results <- get_results(de_proteins)
  
  # Formating data_results
  de_cols <- colnames(data_results)
  centered_cols <- de_cols[str_detect(de_cols, "_centered$")] # Select Centered columns
  ratio_col <- de_cols[str_detect(de_cols, "_vs_.*_ratio$")] # select ratio column (log2FC)
  pval_cols <- de_cols[str_detect(de_cols, "_vs_.*_p\\.val$")] # select pval
  padj_cols <- de_cols[str_detect(de_cols, "_vs_.*_p\\.adj$")] # select padj
  sig_contrast <- de_cols[str_detect(de_cols, "_vs_.*_significant$")] # select significant column
  
  data_results_clean <- data_results %>%
    select(
      name,
      ID,
      all_of(centered_cols),
      all_of(ratio_col),
      all_of(pval_cols),
      all_of(padj_cols),
      all_of(sig_contrast)
    ) %>%
    # renombrar ratio → log2FC
    rename(log2FC = all_of(ratio_col))
  
  rm(de_cols, centered_cols, ratio_col, pval_cols, padj_cols, sig_contrast)
  
  addWorksheet(wb, "DE_Result")
  writeDataTable(wb, sheet = "DE_Result", x = data_results_clean)
  
  # 2.Visualizations
  print("Creating some visualizations")
  # PCA
  de_pca <- plot_pca(de_proteins, x = 1, y = 2, n = 500, point_size = 4,
                     indicate = "condition", label = T) + 
    color_scale_color
  
  save_ggplot(de_pca, title = "DE_Proteins_PCA", folder = individual_plots_dir, 
              width = 3000, height = 2000)
  
  # Hierarchical clustering
  de_proteins_heatmap <- plot_heatmap(de_proteins, type = "centered", kmeans = TRUE, #k = 2,
               col_limit = 4, show_row_names = T,
               indicate = c("condition"), plot = T)
  
  png(filename = file.path(output_dir, "05_DE_Proteins_Heatmap.png"), 
      res = 300, width = 3000, height = 2000)
  print(de_proteins_heatmap)
  dev.off()
  
  # VolcanoPlot
  volcano_plot <- plot_volcano(de_proteins, contrast = "rd10_vs_WT", 
                               label_size = 2, add_names = TRUE, plot = FALSE) %>%
    mutate(
      threshold = factor(
        ifelse(log2_fold_change > 1 & significant, "UP",
               ifelse(log2_fold_change < -1 & significant, "DOWN", "NA")),
        levels = c("DOWN", "NA", "UP")
      ),
      labels = ifelse(significant, protein, NA)
    ) %>%
    ggplot(aes(x = log2_fold_change, y = `p_value_-log10`)) +
    
    geom_point(aes(color = threshold), size = 3) +
    
    ggrepel::geom_text_repel(
      aes(label = labels),
      size = 4,
      show.legend = FALSE,
      min.segment.length = 0,
      seed = 42,
      box.padding = 0.5,
      max.overlaps = Inf,
      segment.size = 0.5
    ) +
    geom_hline(yintercept = -log10(0.01), linetype = "dashed") +
    geom_hline(yintercept = -log10(0.05), linetype = "dashed") +
    geom_vline(xintercept = -1, linetype = "dashed") +
    geom_vline(xintercept = +1, linetype = "dashed") +
    
    labs(
      x = expression(paste("log"[2], "(Fold Change)")),
      y = expression(paste("-log"[10], "(P-value)"))
    ) +
    
    scale_color_manual(values = c('#7B1FA2', 'grey70', "#FBC02D")) +
    
    theme(
      legend.position = 'none',
      axis.text.x = element_text(face = "bold", size = 14),
      axis.text.y = element_text(face = "bold", size = 14)
    ) +
    ggtitle(label = "VolcanoPlot")
  
  save_ggplot(volcano_plot, title = "DE_Proteins_VolcanoPlot", folder = individual_plots_dir,
              width = 3000, height = 2000)
  
  # p-value distribution
  ## Plot histogram of raw p-values
  pval_distribution <- data_results %>%
    ggplot(aes(x = rd10_vs_WT_p.val)) +
    geom_histogram(binwidth = 0.025) +
    labs(x = "P-value", y = "Frequency") +
    ggtitle("P-value distribution following Limma eBayes trend model") +
    theme_bw()
  
  save_ggplot(pval_distribution, title = "Pvalue_Distribution", folder = individual_plots_dir,
              width = 3000, height = 2000)
  
  # Visualizations
  print("Creating DE Figure")
  de_figure <- volcano_plot + (cor_heatmap / (de_pca + pval_distribution))
  de_figure <- de_figure + plot_annotation(title = "Differential Abundance Analysis Result",
                                           tag_levels = "A",
                                           theme = theme(title=element_text(size = 20, hjust = 0.5, face = "bold")))
  
  save_ggplot(de_figure, title = "DE_Result", 
              folder = output_dir, width = 4500, height = 3000)
  
  print_centered_note(toupper("Saving DE_Report.xlsx"))
  saveWorkbook(wb, file.path(output_dir, "DE_Report.xlsx"))
  
  print_centered_note(toupper("End of the script"))
  # ================================================== #
  # ==== BLOCK 10: FUNCTIONAL ENRICHMENT ANALYSIS ====
  # ================================================== #
} # Main function key
