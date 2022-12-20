library(shiny)
library(data.table)

ggplot2::theme_set(ggplot2::theme_bw())
ggplot2::theme_update(plot.caption = ggplot2::element_text(face = "bold", hjust = 0))
captionlab <- paste0("Ferenci Tamás, http://www.medstat.hu/\nhttps://github.com/tamas-ferenci/",
                     "KorhazakTeruletiEllatasiKotelezettsege")

TEKData <- readRDS("TEKres_full_20221207.rds")
megyedata <- readRDS("megyedata.rds")
geodata <- readRDS(url("https://github.com/tamas-ferenci/MagyarorszagKozutiElerhetoseg/raw/main/geodata.rds"))

options(DT.options = list(language = list(url = "https://cdn.datatables.net/plug-ins/1.13.1/i18n/hu.json")))

ui <- fluidPage(
  theme = "owntheme.css",
  
  tags$style(".shinybusy-overlay {opacity: 0; background-color: #7c7c7c;}"),
  shinybusy::add_busy_spinner("fading-circle", position = "full-page"),
  
  tags$head(
    tags$script(async = NA, src = "https://www.googletagmanager.com/gtag/js?id=UA-19799395-3"),
    tags$script(HTML("
    window.dataLayer = window.dataLayer || [];
    function gtag(){dataLayer.push(arguments);}
    gtag('js', new Date());
                       
    gtag('config', 'UA-19799395-3');
    ")),
    tags$meta(name = "description", content = paste0("Kórházak területi ellátási kötelezettségeit ",
                                                     "megjelenítő és vizsgáló alkalmazás. ",
                                                     "Írta: Ferenci Tamás.")),
    tags$meta(property = "og:title", content = "TEK Lekérdező"),
    tags$meta(property = "og:type", content = "website"),
    tags$meta(property = "og:locale", content = "hu_HU"),
    tags$meta(property = "og:url", content = "https://research.physcon.uni-obuda.hu/TEKLekerdezo/"),
    tags$meta(property = "og:image", content = "https://research.physcon.uni-obuda.hu/TEKLekerdezoImage.png"),
    tags$meta(property = "og:description", content = paste0("Kórházak területi ellátási kötelezettségeit ",
                                                            "megjelenítő és vizsgáló alkalmazás. ",
                                                            "Írta: Ferenci Tamás.")),
    tags$meta(name = "DC.Title", content = "TEK Lekérdező"),
    tags$meta(name = "DC.Creator", content = "Ferenci Tamás"),
    tags$meta(name = "DC.Subject", content = "Területi ellátási kötelezettség"),
    tags$meta(name = "DC.Description", content = paste0("Kórházak területi ellátási kötelezettségeit ",
                                                        "megjelenítő és vizsgáló alkalmazás. ")),
    tags$meta(name = "DC.Publisher",  content = "https://research.physcon.uni-obuda.hu/TEKLekerdezo/"),
    tags$meta(name = "DC.Contributor", content = "Ferenci Tamás"),
    tags$meta(name = "DC.Language", content = "hu_HU"),
    
    tags$style(HTML(".leaflet-container { background: #FFF; }"))
  ),
  
  tags$div(id="fb-root"),
  tags$script(async = NA, defer = NA, crossorigin = "anonymous",
              src = "https://connect.facebook.net/hu_HU/sdk.js#xfbml=1&version=v15.0"),
  
  tags$style(".shiny-file-input-progress {display: none}"),
  
  titlePanel("TEK Lekérdező"),
  
  p("A program használatát részletesen bemutató súgó, valamint a technikai részletek",
    a("itt", href = "https://github.com/tamas-ferenci/KorhazakTeruletiEllatasiKotelezettsege",
      target = "_blank"), "olvashatóak el. A TEK adatok letöltésének dátuma: 2022. december 7."),
  div(class = "fb-share-button", "data-href" = "https://research.physcon.uni-obuda.hu/TEKLekerdezo/",
      "data-layout" = "button_count", "data-size" = "small"),
  a(target = "_blank",
    href="https://www.facebook.com/sharer/sharer.php?u=https://research.physcon.uni-obuda.hu/TEKLekerdezo/",
    class="fb-xfbml-parse-ignore"),
  a(href = "https://twitter.com/intent/tweet?url=https://research.physcon.uni-obuda.hu/TEKLekerdezo/",
    "Tweet", class="twitter-share-button"),
  includeScript("http://platform.twitter.com/widgets.js"),
  
  sidebarLayout(
    sidebarPanel(
      selectInput("feladat", "Feladat", c("TEK lekérdezése adott településhez" = "telepules",
                                          "TEK lekérdezése adott szakmához" = "szakma",
                                          "TEK lekérdezése adott kórházhoz" = "korhaz")),
      conditionalPanel("input.feladat=='telepules'",
                       selectizeInput("telepules", "Település", choices = NULL),
                       selectInput("telepulesprog", "Progresszivitási szint", choices = NULL),
                       selectInput("telepulestipus", "Típus", choices = NULL)),
      conditionalPanel("input.feladat=='szakma'",
                       selectizeInput("szakmanev", "Szakma", setNames(sort(unique(paste0(TEKData$SzakmaNev))),
                                                                      sort(unique(paste0(TEKData$SzakmaNev, " (", TEKData$SzakmaKod, ")"))))),
                       selectInput("szakmaprog", "Progresszivitási szint", choices = NULL),
                       selectInput("szakmatipus", "Típus", choices = NULL)),
      conditionalPanel("input.feladat=='korhaz'",
                       selectizeInput("korhaznev", "Kórház", sort(unique(TEKData$KorhazNev))),
                       selectInput("korhazszakma", "Szakma", choices = NULL),
                       selectInput("korhazprog", "Progresszivitási szint", choices = NULL),
                       selectInput("korhaztipus", "Típus", choices = NULL)),
      radioButtons("terkep", "Térkép típusa", c("Statikus", "Interaktív")),
      width = 2
    ),
    
    mainPanel(
      tabsetPanel(
        tabPanel("Térkép",
                 conditionalPanel("input.terkep=='Statikus'", plotOutput("mainPlot", height = "70vh")),
                 conditionalPanel("input.terkep=='Interaktív'", leaflet::leafletOutput("mainPlotInt", height = "70vh")),
                 p("A hiányzó adatok (fehér foltok a térképen, nem hozzá rendelt felirat a táblában) arra utalnak, hogy a TEK adatbázisa hibás; részleteket lásd a kapcsolódó dolgozatban.")),
        tabPanel("Táblázat",
                 DT::DTOutput("mainTab"),
                 p("A hiányzó adatok (fehér foltok a térképen, nem hozzá rendelt felirat a táblában) arra utalnak, hogy a TEK adatbázisa hibás; részleteket lásd a kapcsolódó dolgozatban.")),
        tabPanel("Statisztikák",
                 DT::DTOutput("statTab"),
                 p("A hiányzó adatok (fehér foltok a térképen, nem hozzá rendelt felirat a táblában) arra utalnak, hogy a TEK adatbázisa hibás; részleteket lásd a kapcsolódó dolgozatban."))
      ), width = 10)
  ),
  hr(),
  h4("Írta: Ferenci Tamás (Óbudai Egyetem, Élettani Szabályozások Kutatóközpont), v1.00"),
  
  tags$script(HTML("var sc_project=11601191; 
                      var sc_invisible=1; 
                      var sc_security=\"5a06c22d\";
                      var scJsHost = ((\"https:\" == document.location.protocol) ?
                      \"https://secure.\" : \"http://www.\");
                      document.write(\"<sc\"+\"ript type='text/javascript' src='\" +
                      scJsHost+
                      \"statcounter.com/counter/counter.js'></\"+\"script>\");" ),
              type = "text/javascript")
)

server <- function(input, output, session) {
  
  shinylogs::track_usage(storage_mode = shinylogs::store_rds(path = "logs/"))
  
  updateSelectizeInput(session, "telepules", choices = sort(unique(TEKData$Telepules)), server = TRUE)
  
  observeEvent(input$telepules, {
    freezeReactiveValue(input, "telepulesprog")
    updateSelectInput(inputId = "telepulesprog", choices = sort(unique(TEKData[Telepules==input$telepules]$ProgClean)))
  })
  observeEvent(input$telepulesprog, {
    freezeReactiveValue(input, "telepulestipus")
    updateSelectInput(inputId = "telepulestipus", choices = sort(unique(TEKData[Telepules==input$telepules&ProgClean==input$telepulesprog]$Tipus)))
  })
  
  
  observeEvent(input$szakmanev, {
    freezeReactiveValue(input, "szakmaprog")
    updateSelectInput(inputId = "szakmaprog", choices = sort(unique(TEKData[SzakmaNev==input$szakmanev]$ProgClean)))
  })
  observeEvent(input$szakmaprog, {
    freezeReactiveValue(input, "szakmatipus")
    updateSelectInput(inputId = "szakmatipus", choices = sort(unique(TEKData[SzakmaNev==input$szakmanev&ProgClean==input$szakmaprog]$Tipus)))
  })
  
  observeEvent(input$korhaznev, {
    freezeReactiveValue(input, "korhazszakma")
    updateSelectInput(inputId = "korhazszakma",
                      choices = setNames(sort(unique(paste0(TEKData[KorhazNev==input$korhaznev]$SzakmaNev))),
                                         if(length(sort(unique(paste0(TEKData[KorhazNev==input$korhaznev]$SzakmaNev))))==0) character(0) else
                                           sort(unique(paste0(TEKData[KorhazNev==input$korhaznev]$SzakmaNev, " (",
                                                              TEKData[KorhazNev==input$korhaznev]$SzakmaKod, ")")))))
  })
  observeEvent(input$korhazszakma, {
    freezeReactiveValue(input, "korhazprog")
    updateSelectInput(inputId = "korhazprog", choices = sort(unique(TEKData[KorhazNev==input$korhaznev&SzakmaNev==input$korhazszakma]$ProgClean)))
  })
  observeEvent(input$korhazprog, {
    freezeReactiveValue(input, "korhaztipus")
    updateSelectInput(inputId = "korhaztipus", choices = sort(unique(TEKData[KorhazNev==input$korhaznev&SzakmaNev==input$korhazszakma&ProgClean==input$korhazprog]$Tipus)))
  })
  
  dataTelepules <- reactive({
    TEKData[Telepules==input$telepules&ProgClean==input$telepulesprog&Tipus==input$telepulestipus,
            .(N = (log(.N)+1)*5, lab = paste0(paste0(SzakmaNev, " (", SzakmaKod, ")"), collapse = "<br>"), Duration = Duration[1],
              TelephelyX = TelephelyX[1], TelephelyY = TelephelyY[1],
              TelepulesX = TelepulesX[1], TelepulesY = TelepulesY[1]),
            .(Telephely.városa, Korhaz)]
  })
  dataSzakma <- reactive({
    merge(geodata,
          TEKData[SzakmaNev==input$szakmanev&ProgClean==input$szakmaprog&Tipus==input$szakmatipus,
                  .(NAME = Telepules, Telephely.városa, Korhaz, ProgClean, Duration, SzakmaNev, SzakmaKod, Tipus, Lakó.népesség)],
          all.x = TRUE)
  })
  dataKorhaz <- reactive({
    merge(geodata, TEKData[KorhazNev==input$korhaznev&SzakmaNev==input$korhazszakma&
                             ProgClean==input$korhazprog&Tipus==input$korhaztipus,
                           .(NAME = Telepules, Telephely.városa, TelephelyX, TelephelyY, Korhaz, ProgClean, Tipus, Duration, Lakó.népesség)],
          all.x = TRUE)
  })
  
  
  output$mainPlot <- renderPlot({
    switch(input$feladat,
           "telepules" = {
             req(input$telepules, input$telepulesprog, input$telepulestipus)
             ggplot2::ggplot(dataTelepules()) + ggplot2::geom_sf(data = megyedata) +
               ggplot2::geom_point(ggplot2::aes(x = TelepulesX[1], y = TelepulesY[1]), color = "red") +
               ggplot2::geom_point(ggplot2::aes(x = TelephelyX, y = TelephelyY, size = N)) + ggplot2::guides(size = "none") +
               ggplot2::geom_segment(ggplot2::aes(x = TelepulesX[1], y = TelepulesY[1], xend = TelephelyX, yend = TelephelyY)) +
               ggplot2::labs(x = "", y = "", title = input$telepules, caption = captionlab,
                             subtitle = paste0("Progresszivitási szint: ", input$telepulesprog, ", típus: ",
                                               input$telepulestipus))
           },
           "szakma" = {
             req(input$szakmanev, input$szakmaprog, input$szakmatipus)
             ggplot2::ggplot(dataSzakma(), ggplot2::aes(fill = Telephely.városa)) + ggplot2::geom_sf() +
               ggplot2::guides(fill = ggplot2::guide_legend(ncol = 2)) +
               ggplot2::scale_fill_discrete(na.value = "white") +
               ggplot2::labs(title = input$szakmanev, caption = captionlab,
                             subtitle = paste0("Progresszivitási szint: ", input$szakmaprog, ", típus: ", input$szakmatipus),
                             fill = "Ellátó település")
           },
           "korhaz" = {
             req(input$korhaznev, input$korhazszakma, input$korhazprog, input$korhaztipus)
             dat <- dataKorhaz()
             ggplot2::ggplot(dat, ggplot2::aes(geometry = geometry, fill = is.na(Telephely.városa))) + ggplot2::geom_sf() +
               ggplot2::geom_point(ggplot2::aes(x = dat[!is.na(dat$Telephely.városa),]$TelephelyX[1],
                                                y = dat[!is.na(dat$Telephely.városa),]$TelephelyY[1]), color = "blue") +
               ggplot2::guides(fill = "none") +
               ggplot2::labs(x = "", y = "", title = input$korhaznev, caption = captionlab,
                             subtitle = paste0("Szakma: ", input$korhazszakma, ", progresszivitási szint: ",
                                               input$korhazprog, ", típus: ", input$korhaztipus))
           })
  })
  
  output$mainPlotInt <- leaflet::renderLeaflet({
    switch(input$feladat,
           "telepules" = {
             req(input$telepules, input$telepulesprog, input$telepulestipus)
             temp <- dataTelepules()
             p <- leaflet::leaflet(dataTelepules()) |>
               leaflet::addPolygons(data = megyedata, stroke = TRUE, color = "black", fillColor = "white", weight = 1) |>
               leaflet::addCircleMarkers(lng = ~TelepulesX[1], lat = ~TelepulesY[1], stroke = FALSE, radius = 4, color = "red") |>
               leaflet::addCircleMarkers(lng = ~TelephelyX, lat = ~TelephelyY,
                                         stroke = FALSE, radius = ~N, color = "black",
                                         label = ~lapply(paste0("<strong>", Telephely.városa, "</strong><br>", Korhaz, "<br>Elérési idő: ",
                                                                floor(Duration), " óra ", round((Duration-floor(Duration))*60, 0),
                                                                " perc<br>Szakmák:<br><font size=-3>", lab), htmltools::HTML),
                                         labelOptions = leaflet::labelOptions(
                                           style = list("font-weight" = "normal", padding = "3px 8px"),
                                           textsize = "15px",
                                           direction = "auto"))
             
             for(i in 1:nrow(temp)) p <- leaflet::addPolylines(p, lng = c(temp$TelepulesX[1], temp$TelephelyX[i]),
                                                               lat = c(temp$TelepulesY[1], temp$TelephelyY[i]), color = "black", weight = 1)
             p
           },
           "szakma" = {
             req(input$szakmanev, input$szakmaprog, input$szakmatipus)
             leaflet::leaflet(dataSzakma()) |>
               leaflet::addPolygons(fillColor = ~leaflet::colorFactor(colorRampPalette(RColorBrewer::brewer.pal(9, "Set1"))(length(unique(Telephely.városa))),
                                                                      Telephely.városa)(Telephely.városa),
                                    weight = 1,
                                    opacity = 1,
                                    color = "black",
                                    dashArray = "1",
                                    fillOpacity = 1,
                                    highlightOptions = leaflet::highlightOptions(
                                      weight = 5,
                                      color = "#666",
                                      dashArray = "",
                                      fillOpacity = 0.7,
                                      bringToFront = TRUE),
                                    label = ~lapply(paste0(NAME, "<br><strong>Ellátó település: ", Telephely.városa, "</strong><br>",
                                                           sapply(Korhaz, function(x) paste0(strwrap(x, 50), collapse = "<br>")), "<br>Elérési idő: ",
                                                           floor(Duration), " óra ", round((Duration-floor(Duration))*60, 0),
                                                           " perc"), htmltools::HTML),
                                    labelOptions = leaflet::labelOptions(
                                      style = list("font-weight" = "normal", padding = "3px 8px"),
                                      textsize = "15px",
                                      direction = "auto"))
           },
           "korhaz" = {
             req(input$korhaznev, input$korhazszakma, input$korhazprog, input$korhaztipus)
             leaflet::leaflet() |>
               leaflet::addPolygons(data = dataKorhaz(), stroke = TRUE, color = "black", weight = 1,
                                    fillColor = ~leaflet::colorFactor("viridis", c(TRUE, FALSE))(is.na(Telephely.városa)),
                                    label = ~lapply(NAME, htmltools::HTML),
                                    labelOptions = leaflet::labelOptions(
                                      style = list("font-weight" = "normal", padding = "3px 8px"),
                                      textsize = "15px",
                                      direction = "auto"))
           })
  })
  
  output$mainTab <- DT::renderDataTable({
    switch(input$feladat,
           "telepules" = {
             req(input$telepules, input$telepulesprog, input$telepulestipus)
             DT::datatable(dataTelepules()[
               , .(`Ellátó település` = factor(Telephely.városa),
                   `Kórház` = factor(Korhaz),
                   `Szakmák` = lab, `Elérési idő [h]` = round(Duration, 2))],
               selection = "single", filter = "top", escape = FALSE)
           },
           "szakma" = {
             req(input$szakmanev, input$szakmaprog, input$szakmatipus)
             dat <- data.table(dataSzakma())[, .(NAME, Telephely.városa, Korhaz, ProgClean, Duration, SzakmaNev, SzakmaKod, Tipus, Lakó.népesség)]
             dat <- rbind(dat[!is.na(SzakmaNev)], dat[is.na(SzakmaNev)][
               , .(NAME, Telephely.városa = "X-TEK táblában hozzá nem rendelt", Korhaz = NA, ProgClean = NA, Duration = NA,
                   SzakmaNev = dat[!is.na(SzakmaNev)]$SzakmaNev[1], SzakmaKod = dat[!is.na(SzakmaNev)]$SzakmaKod[1], Tipus = NA, Lakó.népesség = NA)])
             DT::formatCurrency(DT::datatable(dat[
               , .(`Ellátott települések száma` = .N,
                   `Ellátott települések összlakossága` = sum(Lakó.népesség),
                   `Súlyozott átlagos elérési idő [h]` = round(weighted.mean(Duration, Lakó.népesség), 2),
                   `Legrosszabb elérési idő [h]` = round(max(Duration), 2)),
               .(`Ellátó település` = factor(Telephely.városa), `Kórház` = factor(Korhaz), `Szakma` = factor(paste0(SzakmaNev, " (", SzakmaKod, ")")),
                 `Progresszivitási szint` = factor(ProgClean), `Típus` = factor(Tipus))],
               selection = "single", filter = "top"),
               "Ellátott települések összlakossága", currency = "", mark = " ", digits = 0)
           },
           "korhaz" = {
             req(input$korhaznev, input$korhazszakma, input$korhazprog, input$korhaztipus)
             DT::formatCurrency(DT::datatable(data.table(dataKorhaz())[
               !is.na(Telephely.városa), .(`Település` = NAME, `Ellátó település` = Telephely.városa,
                                           `Kórház` = factor(Korhaz),
                                           `Progresszivitási szint` = factor(ProgClean),
                                           `Típus` = factor(Tipus), `Elérési idő [h]` = round(Duration, 2),
                                           `Lakosság` = Lakó.népesség)],
               selection = "single", filter = "top"),
               "Lakosság", currency = "", mark = " ", digits = 0)
           })
  })
  
  output$statTab <- DT::renderDataTable({
    switch(input$feladat,
           "telepules" = {
             req(input$telepules)
             DT::datatable(
               TEKData[Telepules==input$telepules,
                       .(`Ellátó települések száma` = length(unique(Telephely.városa)),
                         `Súlyozott átlagos elérési idő [h]` = round(weighted.mean(Duration, Lakó.népesség), 2),
                         `Legrosszabb elérési idő [h]` = round(max(Duration), 2)),
                       .(`Progresszivitási szint` = factor(ProgClean), `Típus` = factor(Tipus))],
               selection = "single", filter = "top")
           },
           "szakma" = {
             req(input$szakmanev)
             DT::formatCurrency(DT::datatable(
               TEKData[SzakmaNev==input$szakmanev,
                       .(`Ellátott települések száma` = .N,
                         `Ellátott települések összlakossága` = sum(Lakó.népesség),
                         `Súlyozott átlagos elérési idő [h]` = round(weighted.mean(Duration, Lakó.népesség), 2),
                         `Legrosszabb elérési idő [h]` = round(max(Duration), 2)),
                       .(`Szakma` = SzakmaNev, `Progresszivitási szint` = factor(ProgClean), `Típus` = factor(Tipus))],
               selection = "single", filter = "top"),
               c("Ellátott települések száma", "Ellátott települések összlakossága"), currency = "",
               mark = " ", digits = 0)
           },
           "korhaz" = {
             req(input$korhaznev)
             DT::formatCurrency(DT::datatable(
               TEKData[KorhazNev==input$korhaznev,
                       .(`Ellátott települések száma` = .N,
                         `Ellátott települések összlakossága` = sum(Lakó.népesség),
                         `Súlyozott átlagos elérési idő [h]` = round(weighted.mean(Duration, Lakó.népesség), 2),
                         `Legrosszabb elérési idő [h]` = round(max(Duration), 2)),
                       .(`Kórház neve` = KorhazNev, `Szakma` = SzakmaNev, `Progresszivitási szint` = ProgClean, `Típus` = Tipus)],
               selection = "single", filter = "top"), "Ellátott települések összlakossága", currency = "", mark = " ", digits = 0)
           })
  })
  
}

shinyApp(ui = ui, server = server)
