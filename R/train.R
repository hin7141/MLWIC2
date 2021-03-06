#' Train a machine learning model to classify images
#'
#' \code{train} allows users to train their own machine learning model using images
#' that have been manually classified. We recommend having at least 500 images per species,
#' but accuracies will be higher with > 10,000 images. This model will take a very long
#' time to run. We recommend using a GPU if possible. In the \code{data_info} csv, you must
#' have two columns with no headers. Column 1 must be the file name of the image. Column 2
#' must be a number corresponding to the species. Give each species (or group of species) a
#' number identifying it. You can use the \code{make_input} function for help making this csv.
#' The first species must be 0, the next species 1, and so on. If this is your first time using
#' this function, you should see additional documentation at https://github.com/mikeyEcology/MLWIC2 .
#' This function uses absolute paths, but if you are unfamilliar with this
#' process, you can put all of your images, the image label csv ("data_info") and the trained_model folder that you
#' downloaded following the directions at https://github.com/mikeyEcology/MLWIC2 into one directory on
#' your computer. Then set your working directory to this location and the function will find the
#' absolute paths for you.
#'
#' @param path_prefix Absolute path to location of the images on your computer
#' @param data_info csv with file names for each photo (relative path to file). This file must have no headers (column names).
#'  column 1 must be the file name of each image including the extention (i.e., .jpg). Column 2
#'  must be a number corresponding to the species. Give each species (or group of species) a
#'  number identifying it. The first species must be 0, the next species 1, and so on.
#' @param python_loc The location of python on your machine.
#' @param num_gpus The number of GPUs available. If you are using a CPU, leave this as default.
#' @param num_classes The number of classes (species or groups of species) in your model.
#' @param delimiter this will be a `,` for a csv.
#' @param model_dir Absolute path to the location where you stored the trained_model folder
#'  that you downloaded from github.
#' @param os the operating system you are using. If you are using windows, set this to
#'  "Windows", otherwise leave as default
#' @param architecture the architecture of the deep neural network (DNN). Resnet-18 is the default.
#'  Other options are c("alexnet", "densenet", "googlenet", "nin", "vgg")
#' @param depth the number of layers in the DNN. If you are using resnet, the options are c(18, 34, 50, 101, 152).
#'  If you are using densenet, the options are c(121, 161, 169, 201).
#'  If you are an architecture other than resnet or densenet, the number of layers will be automatically set.
#' @param log_dir_train directory where you will store the model information.
#'  This will be called when you what you specify in the \code{log_dir} option of the
#'  \code{classify} function. You will want to use unique names if you are training
#'  multiple models on your computer; otherwise they will be over-written.
#' @param batch_size the number of images simultaneously passed to the model for training.
#'  It must be a multiple of 16. Smaller numbers will train models that are more accurate, but it will
#'  take longer to train. The default is 128.
#' @param retrain If TRUE, the model you train will be a retraining of the model you 
#'  specify in `retrain_from`. If FALSE, you are starting training from scratch. Retraining will be faster
#'  but training from scratch will be more flexible.
#' @param retrain_from name of the directory from which you want to retrain the model.
#' @param num_epochs the number of epochs you want to use for training. The default is 55 and this is
#'  recommended for training a full model. But if you need to start and stop training, you may want to use
#'  a smaller number at times.
#' @param top_n The number of guesses that you want the model to save. This needs to be less than or 
#'  equal to the number of classes.
#' @param num_cores The number of cores you want to use. You can find the number on your computer using
#'  parallel::detectCores()
#' @param randomize If TRUE, this will randomize the order in which images are passed to training
#' @param max_to_keep maximum number of snapshot files to keep. These are the snapshots that are taken of the
#'  current version of the model at the end of each epoch.
#' @param print_cmd print the system command instead of running the function. This is for development.
#' @export
train <- function(
  # set up some parameters for function
  path_prefix = paste0(getwd(), "/images"), # absolute path to location of the images on your computer
  data_info = paste0(getwd(), "/image_labels.csv"), # csv with file names for each photo. See details
  model_dir = paste0(getwd(), "/MLWIC2_helper_files"),
  python_loc = "/anaconda2/bin/",
  os="Mac",
  num_gpus = 2,
  num_classes = 59, # number of classes in model
  delimiter = ",", # this will be , for a csv.
  architecture = "resnet",
  depth = "18",
  batch_size = 128,
  log_dir = "species_model",
  log_dir_train = "MLWIC2_train_output",
  retrain = TRUE,
  retrain_from = "species_model",
  num_epochs = 55,
  top_n = 5,
  num_cores = 1, 
  randomize = TRUE, 
  max_to_keep = 5,
  print_cmd = FALSE,
  shiny=FALSE
) {
  
  wd1 <- getwd() # the starting working directory
  
  # set these parameters before changing directory
  path_prefix = path_prefix
  data_info = data_info
  model_dir = model_dir
  
  # check some numbers
  if(top_n > num_classes){
    stop(paste0("You specified a top_n (", top_n, ") that is greater than num_classes (", num_classes, "). Make sure that top_n <= num_classes."))
  }
  
  # navigate to directory with trained model
  # if(endsWith(model_dir, "/")){
  #   wd <- model_dir #(paste0(model_dir, log_dir))
  # } else {
  wd <- model_dir #(paste0(model_dir, "/", log_dir))
  # }
  #if(shiny==FALSE){
  setwd(wd)
  #}
  
  # add a / to the end of python directory if applicable
  python_loc <- ifelse(endsWith(python_loc, "/"), python_loc, paste0(python_loc, "/"))
  
  # load in data_info and store it in the model_dir
  # labels <- utils::read.csv(data_info, header=FALSE)
  # utils::write.csv(labels, "data_info_train.csv", row.names=FALSE)
  
  if(os=="Windows"){
    # deal with windows cp not working
    data_file <- read.table(data_info, header=FALSE, sep=",")
    output.file <- file("data_info_train.csv", "wb")
    write.table(data_file,
                file = output.file,
                append = TRUE,
                quote = FALSE,
                row.names = FALSE,
                col.names = FALSE,
                sep = ",")
    close(output.file)
    rm(output.file)
  } else {
    cpfile <- paste0("cp ", data_info, " ", wd, "/data_info_train.csv")
    system(cpfile)
  }
  
  
  # set depth
  if(architecture == "alexnet"){
    depth <- 8
  }
  if(architecture == "nin"){
    depth <- 16
  }
  if(architecture == "vgg"){
    depth <- 22
  }
  if(architecture == "googlenet"){
    depth <- 32
  }
  
  # run function
  if(os=="Windows"){
    # if Windows cannot specify log_dir_train
    if(retrain){
      train_py <- paste0(python_loc,
                         "python run.py train", 
                         " --path_prefix ", path_prefix,
                         " --architecture ", architecture,
                         " --depth ", depth,
                         " --num_gpus ", num_gpus,
                         " --batch_size ", batch_size,
                         " --train_info data_info_train.csv",
                         " --delimiter ", delimiter,
                         " --num_epochs ", num_epochs,
                         " --top_n ", top_n, 
                         " --num_threads ", num_cores, 
                         " --num_classes ", num_classes,
                         " --retrain_from ", retrain_from,
                         " --shuffle ", randomize,
                         " --max_to_keep ", max_to_keep,
                         #" --log_dir ", log_dir_train,  # commenting this out-might need to for Windows
                         "\n")
    }else {
      train_py <- paste0(python_loc,
                         "python run.py train", 
                         " --path_prefix ", path_prefix,
                         " --architecture ", architecture,
                         " --depth ", depth,
                         " --num_gpus ", num_gpus,
                         " --batch_size ", batch_size,
                         " --train_info data_info_train.csv",
                         " --delimiter ", delimiter,
                         " --num_epochs ", num_epochs,
                         " --top_n ", top_n, 
                         " --num_threads ", num_cores, 
                         " --num_classes ", num_classes,
                         " --shuffle ", randomize,
                         " --max_to_keep ", max_to_keep,
                         #" --log_dir ", log_dir_train, 
                         "\n")
    }
  } else{
    if(retrain){
      train_py <- paste0(python_loc,
                         "python run.py train", 
                         " --path_prefix ", path_prefix,
                         " --architecture ", architecture,
                         " --depth ", depth,
                         " --num_gpus ", num_gpus,
                         " --batch_size ", batch_size,
                         " --train_info data_info_train.csv",
                         " --delimiter ", delimiter,
                         " --num_epochs ", num_epochs,
                         " --top_n ", top_n, 
                         " --num_threads ", num_cores, 
                         " --num_classes ", num_classes,
                         " --retrain_from ", retrain_from,
                         " --shuffle ", randomize,
                         " --max_to_keep ", max_to_keep,
                         " --log_dir ", log_dir_train,  # commenting this out-might need to for Windows
                         "\n")
    }else {
      train_py <- paste0(python_loc,
                         "python run.py train", 
                         " --path_prefix ", path_prefix,
                         " --architecture ", architecture,
                         " --depth ", depth,
                         " --num_gpus ", num_gpus,
                         " --batch_size ", batch_size,
                         " --train_info data_info_train.csv",
                         " --delimiter ", delimiter,
                         " --num_epochs ", num_epochs,
                         " --top_n ", top_n, 
                         " --num_threads ", num_cores, 
                         " --num_classes ", num_classes,
                         " --shuffle ", randomize,
                         " --max_to_keep ", max_to_keep,
                         " --log_dir ", log_dir_train, 
                         "\n")
    }
  }
 
  
  
  # printing only?
  if(print_cmd){
    print(train_py)
  } else {
    # run code
    toc <- Sys.time()
    # if(shiny){
    #   system(paste0("cd ", wd, "\n", # set directory using system because it can't be done in shiny
    #                 train_py))
    # } else{
    system(train_py)
    # }
    
    tic <- Sys.time()
    runtime <- difftime(tic, toc, units="auto")
    
    # end function
    if(os!="Windows"){
      if(dir.exists(paste0(model_dir, "/", log_dir_train))){
        txt <- paste0("the train function ran for ", runtime, " ", units(runtime),  ". ",
                      "The trained model is in ", log_dir_train, ". ",
                      "Specify this directory as the log_dir when you use classify(). \n")
      } else {
        txt <- paste0("the train function did not run properly.\n")
      }
    } else {
      txt <- paste0("the train function is complete.\n")
    }


    cat(txt)
  }
  
}


