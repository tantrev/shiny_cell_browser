library(shiny)
library(Seurat)
library(plotly)
library(plyr)
library(dplyr)
library(varhandle)
library(DT)
library(rlist)
source("utils.R")

#Start to read in the config file.
json_file <- rjson::fromJSON(file = './data/config.json')
json_data <- json_file$data
datasets <- 1:length(json_data)
dataset_names <- sapply(json_data, function(x) x$name)
dataset_selector <- as.list(c(datasets))
names(dataset_selector) <- c(dataset_names)

#Use only the first dataset in the config file
dataset_name = dataset_names[[1]]
dataset = datasets[[1]]

#Read the config data
config <- json_file$config

#Now read in the data
calc_pt_size <- function(n) {30 / n^0.5}
read_data <- function(x) {
  # load data and metadata specified by the JSON string.
  # x: individual json string, with [name, file, clusters embedding]
  seurat_data <- readRDS(x$file)
  seurat_data <- SetAllIdent(seurat_data,  x$cluster)
  ncells <- length(seurat_data@cell.names)
  pt_size <- calc_pt_size(ncells)
  colors <- seurat_data@misc[[sprintf("%s_colors",  x$cluster)]]
  if (is.null(colors)) {
    set.seed(2)
    colors <- sample(rainbow(n_distinct(seurat_data@ident)))
  }
  genes <- sort(rownames(seurat_data@data))
  
  #Parser additions
  full_embedding <- as.data.frame(GetDimReduction(seurat_data,reduction.type=x$embedding,slot="cell.embeddings"))
  assign_clust <- as.data.frame(GetClusters(seurat_data))
  colorVec = mapvalues(as.integer(assign_clust[,2]), from=1:length(colors), to=toupper(colors)) #1:length(colors)
  df_plot = cbind(full_embedding,assign_clust[,2],colorVec)
  colnames(df_plot) = c("dim1","dim2","cluster","colorVec")
  y_range = max(full_embedding[,2])-min(full_embedding[,2])
  x_domain = max(full_embedding[,1])-min(full_embedding[,1])
  xScaleRatio_clusterPlot = y_range/x_domain
  yScaleRatio_clusterPlot = x_domain/y_range
  coords_title = group_by(df_plot,cluster) %>% dplyr::summarize(x_center = mean(dim1), y_center = mean(dim2))
  
  #Add the full description name on mouse over
  desc_df = list.flatten(x$cluster_dict)
  source_abbv = names(desc_df)
  dest_desc = as.character(list.flatten(x$cluster_dict))
  df_plot$cluster_description = as.character(mapvalues(df_plot$cluster,from = source_abbv,to=dest_desc))
  
  #Differential expression data
  differential_expression = read.csv(file=x$diff_ex, header=TRUE, sep=",")
  plot_tab <- differential_expression # %>% select(-c("id")) #%>% select(-c("id","cluster","is_max_pct","p_val","myAUC","power"))
  
  seurat_data2 <- SetAllIdent(seurat_data,  x$diff_eq_cluster)
  assign_clust2 <- as.data.frame(GetClusters(seurat_data2))
  merged = dplyr::left_join(assign_clust,assign_clust2,by="cell.name")
  keyMap = distinct(merged %>% select(cluster.x,cluster.y))
  
  plot_tab$cluster = as.character(mapvalues(plot_tab$cluster,from = as.integer(keyMap$cluster.y),to=as.character(keyMap$cluster.x)))
  
  return(
    list(
      name = x$name,
      seurat_data = seurat_data,
      ncells = ncells,
      pt_size = pt_size,
      embedding = x$embedding,
      colors = colors,
      genes = genes,
      
      #Parser additions
      plot_df = df_plot,
      x_scale_ratio_clusterPlot = xScaleRatio_clusterPlot,
      y_scale_ratio_clusterPlot = yScaleRatio_clusterPlot,
      title_coords = coords_title,
      diff_eq_table = plot_tab,
      category_order = x$category_order,
      cluster_dict = x$cluster_dict
      
    ))
}

data_list <- lapply(json_data, read_data)

#OLD WAY TO UPDATE EXPRESSION PLOT VIA PLOTLY UPDATE
#updateExpressionPlot <- function(input, output, session, inputGene)
#{
#  updateTextInput(session, "hidden_selected_gene", value = inputGene)
  
  #new_plot_data = GetPlotData(organoid,inputGene)
  #plotlyProxy("expression_plot", session) %>% plotlyProxyInvoke("addTraces",list(type="scattergl",mode="markers",hoverinfo="text",text=as.double(unlist(select(new_plot_data,"gene"))),marker=list(size=2,colors=c("grey90", "red"),color=as.double(unlist(select(new_plot_data,"gene")))),x=as.double(unlist(select(new_plot_data,"dim1"))),y=as.double(unlist(select(new_plot_data,"dim2")))))
  #plotlyProxy("expression_plot", session) %>% plotlyProxyInvoke("deleteTraces",list(0))
  #plotlyProxy("expression_plot", session) %>% plotlyProxyInvoke("relayout",list(title=inputGene))
#}

server <- function(input, output, session){
  
  
  updateSelectInput(session, "selected_dataset", choices=dataset_names, selected=dataset_names[[1]])

  #Updates dataset index on selection and updates gene list
  current_dataset_index <- eventReactive({input$selected_dataset},{
    current_index <- dataset_selector[[input$selected_dataset]]
    return(current_index)
  },ignoreInit = TRUE, ignoreNULL = TRUE)
  
  #Return current organoid and update values
  organoid <- eventReactive({current_dataset_index()},{
    return(data_list[[current_dataset_index()]])
  })
  
  #Update the gene list on change
  observeEvent({organoid()},{
    updateSelectizeInput(session,'selected_gene',choices=organoid()$genes,server=TRUE)
  })
  
  #Update expression plot on click
  observeEvent({
    s <- event_data("plotly_click",source="plot_dot")
    return(!is.null(s$y))
  },{
    s <- event_data("plotly_click",source="plot_dot")
    updateTextInput(session, "hidden_selected_gene", value = s$y)
  },
  ignoreNULL=TRUE, ignoreInit=TRUE)
  
  
  #Update expression plot from selectize input
  observeEvent({input$selected_gene},
               {
                 updateTextInput(session, "hidden_selected_gene", value = input$selected_gene)
               },
               ignoreNULL=TRUE, ignoreInit=TRUE)
  
  #Get plot window width using the cluster plot as a reference
  plot_window_width = eventReactive({session$clientData$output_cluster_plot_width},{
    return(session$clientData$output_cluster_plot_width)
  })
  
  #Get plot window height using the cluster plot as a reference
  plot_window_height = eventReactive({session$clientData$output_cluster_plot_height},{
    return(session$clientData$output_cluster_plot_height)
  })
  
  #Generate the current table based on the current hidden selected cluster
  current_table <- eventReactive({input$hidden_selected_cluster},{
    if(as.character(input$hidden_selected_cluster)==""){
      return(organoid()$diff_eq_table)
    }
    else{
      subTable = filter(organoid()$diff_eq_table,cluster==input$hidden_selected_cluster)
      return(subTable)
    }
  })
  
  #Monitor cluster plot for changes and update hidden_selected_cluster field
  observeEvent({
    s <- event_data("plotly_click",source="plot_cluster")
    return(!is.null(s))
  },{
    s <- event_data("plotly_click",source="plot_cluster")
    if(!is.null(s)){
      updateTextInput(session,"hidden_selected_cluster",value=s$key)
    }
  })
  
  #Set the hidden_selected_cluster field to nothing when the reset button is clicked
  observeEvent(eventExpr = {input$reset_table}, handlerExpr = {
    updateTextInput(session,"hidden_selected_cluster",value="")
    })
  
  #Update the gene table when current_table() changes
  observeEvent({current_table()},{
    dataTableProxy("cluster_gene_table", session, deferUntilFlush = TRUE) %>% replaceData(current_table(), rownames=FALSE)
  })
  
  #Update the dot plot with new gene list
  observeEvent(c({input$gene_list_submit},{current_dataset_index()}),{
    gene_listy <- trimws(strsplit(toupper(input$gene_list), '\n')[[1]])
    filtered_gene_list <- get_shared_genes(gene_listy,organoid()$genes,10)
    updateTextAreaInput(session,"hidden_gene_list",value=paste(filtered_gene_list,collapse=","))
  })
  
  current_gene_list <- eventReactive(c({input$hidden_gene_list},{current_dataset_index()}),{
    gene_listy = strsplit(paste(input$hidden_gene_list,collapse=","),split=",")[[1]]
    return(gene_listy)
  })
  
  ##GRAPHIC OUTPUTS
  output$cluster_plot <- renderPlotly(
    {
      GetClusterPlot(data_list,current_dataset_index(),plot_window_width(),plot_window_height())
    }
  )
  output$expression_plot <- renderPlotly(
    {
      GetExpressionPlot(data_list,current_dataset_index(),input$hidden_selected_gene,plot_window_width(),plot_window_height())
    }
  )
  output$dot_plot <- renderPlotly(
    {
      GetDotPlot(data_list,current_dataset_index(),current_gene_list(),plot_window_width())
    }
  )
  
  clusterString <- eventReactive({input$hidden_selected_cluster},{
    baseString = "all clusters"
    if(input$hidden_selected_cluster!=""){
      baseString = organoid()$cluster_dict[input$hidden_selected_cluster]
    }
    return(sprintf("Genes differentially expressed in %s",baseString))
  })
  
  #TABLE OUTPUT
  #Format the cluster gene table and add links to Addgene and ENSEMBL
  output$cluster_gene_table_title <- renderText({clusterString()})
  output$cluster_gene_table <- 
    DT::renderDT({
      datatable(organoid()$diff_eq_table,
                rownames=FALSE,
                extensions=c('Responsive'),
                options=
                  list(
                    columnDefs=
                      list(
                        list(responsivePriority=1,targets=c(0,7,9)),
                        list(responsivePriority=2,targets=c(3,4,5)),
                        list(
                          render= JS(
                            "function(data, type, row, meta) {",
                            "return type === 'display'?",
                            "'<a href=\"https://www.genecards.org/cgi-bin/carddisp.pl?gene=' + data + '\">' + data + '</a>' : data;",
                            "}"), targets=c(0)),
                        list(
                          render= JS(
                            "function(data, type, row, meta) {",
                            "return type === 'display'?",
                            "'<a href=\"http://uswest.ensembl.org/Homo_sapiens/Gene/Summary?g=' + data + '\">' + data + '</a>' : data;",
                            "}"), targets=c(1))
                      )
                  )) %>% formatPercentage(c('pct.1','pct.2'), 0) %>% formatSignif(c('avg_logFC','p_val','p_val_adj'),3)
    },
    server=TRUE
    )
}