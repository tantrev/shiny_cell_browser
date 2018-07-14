
## Shiny Single Cell Browser

Interactive visualization of single cell RNAseq datasets


07-14-2018

  - Add Plotly interactive mode. Click on a gene in the dot plot to show it's distribution on t-SNE/UMAP.
  - The interactive mode require the new ggplot2 3.0.0 and dev branch of plotly. `devtools::install_github("ropensci/plotly")`
  - Non-interactive mode works for both ggplot2 2.2.1 and 3.0.0 

07-13-2018

  - Visualize two datasets simultaneously. Can easily switch beteen more datasets from dropdown menu.
  - Visualize cluster distribution on UMAP/t-SNE plots.
  - Plot the expression pattern of individual marker genes on UMAP/t-SNE embeddings.
  - Plot cluster-averaged expression of gene lists using dot plots.
  - Automatic resizing/scaling of figures to fit different browser windows and screen resolutions.
  - Export publication-quality figures in PDF and PNG formats. (use manual scaling for consistency)
  - Specify pre-analyzed datasets in the JSON config file (see `example_config.json`).
  - Currently support Seurat format.


### Setting up the App
  
  - To download the App, `git clone git@github.com:yueqiw/shiny_cell_browser.git`
  - To update, `cd shiny_cell_browser` then `git pull`
  - Store Seurat data objects as `.rds` files 
  - Optionally, store cluster colors as a vector in `seurat_data@misc[[sprintf("%s_colors", cluster_name)]]`
  - Specify the file paths, clustering results and 2D embeddings in `config.json` file. Follow the example in `example_config.json`. The App will automatically open the first two files. 
  - To launch Single Cell Browser locally: run the following code.  
  ```
  cd shiny_cell_browser
  R -e "shiny::runApp('./', port=1234)
  ## or store the lunch script in run_app.sh and run the following
  ./run_app.sh 
  ```
  - This should launch the web browser at `http://127.0.0.1:1234/`
  - If you want other computers in the local network to access the web app, run `R -e "shiny::runApp('./', host='0.0.0.0' port=1234)`. Then visit `your-ip-address:1234`
  
Example `config.json` file: 

```
{
    "data": [
        {
            "name": "My favorite sample",
            "file": "path/to/seurat/data.rds",
            "clusters": "res.1",
            "embedding": "umap_1"
        },
        {
            "name": "My 2nd favorite sample",
            "file": "path/to/seurat/data.rds",
            "clusters": "res.1",
            "embedding": "tsne_1"
        }
    ]
}
```

### Dependencies

  - R==3.4.3 or 3.5.0
  - Seurat==2.3.2
  - rjson==0.2.15
  - shiny==1.1.0
  - shinyjs==1.0
  - tidyverse==1.2.1
  - ggplot2==2.2.1

For plotly interactive mode, install ggplot2 3.0.0 and developmental branch of plotly
  - ggplot2==3.0.0
  - plotly==4.7.1
