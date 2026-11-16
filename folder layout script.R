dirs <- c("data/raw", "data/interim","data/processed",
          "R", "scripts", "analysis","outputs/figures","outputs/tables",
          "report","dashboard","docs"
          )

for (d in dirs){
  dir.create(
    d,
    recursive = TRUE,
    showWarnings = FALSE
  )
  
  file.create(
    file.path(d,".gitkeep")
    )
}


