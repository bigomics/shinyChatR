
#' @title A chat module for Shiny apps - UI
#'
#' @description Creates the user interface for the chat module, which includes a chat message display area, a text input field for entering new messages, and a send button.
#'
#' @param id The id of the module
#' @param height The height of the chat display area. Default is 300px.
#' @param width The width of the chat display area. Default is 500px.
#'
#' @import shiny
#'
#' @export
#'
chat_ui <- function(id, title='', height = "300px", width = "500px") {

  ns <- NS(id)

  div(
    includeCSS(system.file("assets/shinyChatR.css", package = "shinyChatR")),
    div(class = "chatContainer",
        div(class = "chatTitle", title),
        div(class = "chatMessages", ## width = width,
            style = paste0("height:", height,";width:",width,";"),
            # Display messages here
            uiOutput(ns("chatbox"))
        ),
        tags$form(class = "chatForm",
                  tags$input(type = "text",
                             id = ns("chatInput"),
                             placeholder = "Enter message"),
                  actionButton(inputId = ns("chatFromSend"),
                    ##                               label = "Send",
                               label = NULL,                    
                               width = "70px",
                               icon = icon("paper-plane"),
                               style = "background-color: #007bc2;
                                        color: #fff; height:32px;padding:0px;")
        )
    )
  )
}

#' @title A chat module for Shiny apps - server
#'
#' @description Creates the server logic for the chat module, which handles adding new messages to the database or RDS file, and retrieving messages to display
#'
#' @param id The id of the module.
#' @param chat_user The user name that should be displayed next to the message.
#' @param db_connection A database connection object, created using the \code{DBI} package. If provided, the chat messages will be stored in a database table.
#' @param db_table_name he name of the database table to use for storing the chat messages. If \code{db_connection} is provided, this parameter is required.
#' @param rds_path The path to an RDS file to use for storing the chat messages. If provided, the chat messages will be stored in an RDS file instead of a database.
#' @param invalidateDSMillis The milliseconds to wait before the data source is read again. The default is 1 second.
#'
#' @return the reactive values \code{chat_rv} with all the chat information
#'
#' @import shiny
#' @importFrom R6 R6Class
#' @importFrom DBI dbGetQuery dbExecute
#'
#' @export
#'
chat_server <- function(id,
                        chat_user,
                        db_connection = NULL,
                        db_file = NULL,                        
                        db_table_name = "chat_data",
                        rds_path = NULL,
                        csv_path = NULL,                        
                        invalidateDSMillis = 1000,
                        pretty = TRUE,
                        nlast = 100
                        ) {

  moduleServer(
    id,
    function(input, output, session) {

      ns <- session$ns

      # data source can only be a db or rds file
      if (sum(!is.null(c(db_connection,rds_path,csv_path,db_file)))>1){
        stop("Either specify only one DB connection, DB file, RDS or CSV path")
      }
      if(!is.null(db_connection)) {
        stop("Please use db_file instead of db_connection")
      }

      # initiate data source R6
      if (!is.null(db_connection) || !is.null(db_file)){
        ChatData <- DBConnection$new(db_connection, db_table_name, db_file)
        # check if it contains the necessary variables
        if (!all(c("text", "user", "time") %in% names(ChatData$get_data()))){
          stop("The dataframe does not have the necessary columns text, user and time")
        }
      } else if (!is.null(rds_path)){
        ChatData <- RDSConnection$new(rds_path)
        if (!all(c("text", "user", "time") %in% names(ChatData$get_data()))){
          stop("The dataframe does not have the necessary columns text, user and time")
        }
      } else if (!is.null(csv_path)){
        ChatData <- CSVConnection$new(csv_path, n=nlast)
        if (!all(c("text", "user", "time") %in% names(ChatData$get_data()))){
          stop("The dataframe does not have the necessary columns text, user and time")
        }
      } else {
        stop("Either 'db_connection', 'rds_path' or 'csv_path' must be specified.")
      }

      ## get non-NULL file
      data_file <- c(db_file,rds_path,csv_path)[1]
      reactive_chatData <- shiny::reactiveFileReader(
        invalidateDSMillis, session, data_file, function(f) ChatData$get_data()
      ) 
        
      # Add code for sending and receiving messages here
      chat_rv <- reactiveValues(chat = ChatData$get_data())

      output$chatbox <- renderUI({
        if (nrow(chat_rv$chat)>0) {
          # prepare the message elements
          render_msg_divs2(
              chat_rv$chat$text,
              chat_rv$chat$user,
              # check if it is a reactive element or not
              ifelse(is.reactive(chat_user), chat_user(), chat_user),
              strftime(chat_rv$chat$time),
              pretty = pretty
          )
        } else {
          tags$span(" ")
        }
      })

      observe({
        # reload chat data
        chat_rv$chat <- reactive_chatData()        
      })

      observeEvent( input$chatFromSend, {
        if(input$chatInput=="") return()
        ChatData$insert_message(
          user = ifelse(is.reactive(chat_user), chat_user(), chat_user),
          message = input$chatInput,
          time = strftime(Sys.time())          
        )
        ## chat_rv$chat <- ChatData$get_data()  ## not needed??
        updateTextInput(session, "chatInput", value='')
      })

      return(chat_rv)
    })
}
