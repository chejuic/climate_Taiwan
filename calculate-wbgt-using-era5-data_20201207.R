#目的: 測試使用ERA5資料繪製WBGT地理分布

# 希望有幫助到您，有問題可以再跟我說XD

# 步驟說明:
# 1.下載ERA5氣象資料(台灣區域)
# 2.利用氣象資料計算WBGT
# 3.繪製WBGT地理分布圖

if(!"reticulate"%in%installed.packages()) installed.packages("reticulate")
if(!"raster"%in%installed.packages()) installed.packages("raster")
if(!"ncdf4"%in%installed.packages()) installed.packages("ncdf4")
if(!"lubridate"%in%installed.packages()) installed.packages("lubridate")
if(!"sp"%in%installed.packages()) installed.packages("sp")
if(!"sf"%in%installed.packages()) installed.packages("sf")
if(!"rgdal"%in%installed.packages()) installed.packages("rgdal")

library(reticulate) # for using python in R code
library(raster) # for processing of raster data
library(ncdf4) # for read netCDF data
library(lubridate) # for dealing with Date data
# for geographic data analysis
library(sp)  
library(sf)  
library(rgdal)

# 設定工作目錄
setwd("B:/r/version control/temperature data/demo")
getwd()

# 1.下載ERA5氣象資料(台灣區域) #####

# 主要透過Climate Data Store(CDS) API下載ERA5資料
# CDS API在 python 和 R 都有package可以直接使用
# 1. python 套件名稱是 cdsapi 
# 2. R 套件名稱是 ecmwfr
# ecmwfr package source:
# https://cran.r-project.org/web/packages/ecmwfr/vignettes/cds_vignette.html

# 目前是以 python cdsapi pacakge 測試

# 1.1 使用python #####
# 由於使用的是 python 的 package 
# 所以需要先透過anaconda安裝python開發環境
# anaconda下載網址:
# https://docs.anaconda.com/anaconda/install/windows/
# 才能安裝package
use_python("C:/Users/HY/anaconda3/envs/r-reticulate/python.exe")

# 1.2 安裝 python cdsapi package #####
py_install(
  packages = "cdsapi",
  envname = "r-reticulate",
  method = "conda",
  pip = T
)

# 1.3 透過套件檔案儲存的路徑匯入cdsapi package #####
cdsapi <- import_from_path("cdsapi", path = "c:/users/hy/anaconda3/envs/r-reticulate/lib/site-packages", convert = T)

# 1.4 設定使用者金鑰 #####

# 使用cdsapi package必須至Climate Data Store 網頁註冊 & 同意資料使用條款
# 步驟一: Climate Data Store 網頁註冊
# https://cds.climate.copernicus.eu/cdsapp#!/home

# 步驟二: 取得Climate Data Store API 的 url 和 key
# 登入帳戶後，進入api使用說明頁面
# https://cds.climate.copernicus.eu/api-how-to
# 在右方黑色視窗取得 "url" 和 "key"
#
# url: https://cds.climate.copernicus.eu/api/v2
# key: 66755:83b334e2-309f-4029-9f80-2666fa051eab
# 並在一開始使用API時，設定相關參數，不然會一直顯示"self參數未設定"的訊息

# 步驟三: 接受資料使用條款
# 登入cds climate帳戶，進入下列網頁
# https://cds.climate.copernicus.eu/cdsapp/#!/terms/licence-to-use-copernicus-products
# 且接受下列網址的條款: 
# Step 1: 勾選 "Confirm your acceptance of these terms by ticking this box and submitting."
# Step 2: 點選Submitted即可

c <- cdsapi$Client(url = "https://cds.climate.copernicus.eu/api/v2", key = "66755:83b334e2-309f-4029-9f80-2666fa051eab")

#  1.5 透過 cdsapi 傳遞參數下載台灣ERA5資料#####

# 目前以台灣 2019年1-12月 月平均值 作為測試資料

# 室外WBGT公式(Liljegren)需要的參數 :
# [ERA5對應的參數名稱(單位)]
# 1. temperature in degC. 
#    [2m temperature(K)]

# 2. dewpoint temperature in degC.
#    [2m dewpoint temperature(K)]

# 3. wind speed in m/s.
#    [10m wind speed(m s-1)]

# 4. solar shortwave downwelling radiation in W/m2.
#    [Mean surface direct short-wave radiation flux(W m-2)]

# 5. date [time]
# 6. longitude [longitude]
# 7. latitude [latitude]

# 參考資料:
# 一.由於無法觀看原作者Liljegren的論文全文，
# 下方文獻詳細定義室外WBGT公式的輻射參數是使用direct short wave radiation
# Lemke, B., & Kjellstrom, T. (2012). Calculating Workplace WBGT from Meteorological Data: A Tool for Climate Change Assessment. Industrial Health, 50(4), 267-278. doi:DOI 10.2486/indhealth.MS1352

# 二.室外WBGT公式(Liljegren) 可用R的HeatStress package中wbgt.Liljegren函數計算
# source: 
# https://rdrr.io/github/anacv/HeatStress/man/wbgt.Liljegren.html

# 三. ERA5月平均值參數說明
# source: 
# https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-era5-single-levels-monthly-means

# 1.5.1 設定ERA5檔案路徑 ####
# 注意副檔名為.nc 為 NetCDF 檔案格式
# ERA5資料型態說明 
# source:
# https://confluence.ecmwf.int/display/CKB/ERA5%3A+What+is+the+spatial+reference
# NetCDF 資料儲存格式是一個時間點一張圖，有經緯度和時間三個軸
# source: https://pro.arcgis.com/en/pro-app/help/data/imagery/GUID-D872A4C3-749E-4159-A6C0-FB6D3B47C5D8-web.gif

ncfilename <- paste0(getwd(),"/ERA5/ERA5_2019_wbgt_var_TW_.nc")

# 1.5.2 ERA5資料中WBGT所需變數設定 ####
#注意: 
# short-wave 要改成 short_wave，Mean改成mean，不然會無法使用變數
# time , longitude 和 latitude是原本就一定會有的變數所以不用設定
var <- c("2m_temperature","2m_dewpoint_temperature","10m_wind_speed","mean_surface_direct_short_wave_radiation_flux")

# 1.5.3 由CDS API傳遞參數取得ERA5資料 ####

# 資料期間為2019年1-12月

ResultUrl <- c$retrieve(
  name = 'reanalysis-era5-single-levels-monthly-means', request = list(
    product_type = 'monthly_averaged_reanalysis',
    variable = var, #設定所需變數名稱
    year = '2019', #設定年份
    month = formatC(1:12, width = 2,flag = "0"), #設定月份
    time = '00:00', #設定時間，'00:00'是月平均值的特殊設定
    grib = c(0.25,0.25), #設定解析度
    area = c(25.47,119.27,21.7,122.06) , # 設定區域範圍
    format = 'netcdf'), #設定檔案格式
    target = ncfilename #設定下載後的檔案位置
)

# 可參考ERA5 family datasets範例中的說明，以設定CDS API傳遞的參數
# source:
# https://confluence.ecmwf.int/display/CKB/Climate+Data+Store+%28CDS%29+API+Keywords


# 2.利用氣象資料計算WBGT #####

# 2.1 匯入計算室外WBGT公式(Liljegren)的package ####

# 如果不是使用Rtools40和R 4.0.3才需進行下列步驟
# install HeatStress package for wbgt calculation
# 1. 移除Rtools35，改安裝Rtools40
# 2. 重新安裝R 4.0.3和RStudio-1.3.1093
# 3. run下面這兩行
writeLines('PATH="${RTOOLS40_HOME}\\usr\\bin;${PATH}"', con = "~/.Renviron")
update.packages(ask=FALSE, checkBuilt=TRUE)
# .............................................

# 開始安裝anacv/HeatStress
if(!"remotes"%in%installed.packages()) installed.packages("remotes")
remotes::install_github("anacv/HeatStress" , force = T)

#匯入HeatStress package
library(HeatStress)

# 2.2 匯入ERA5資料 ####

# ERA5資料檔案路徑
ncfilename <- paste0(getwd(),"/ERA5/ERA5_2019_wbgt_var_TW_.nc")

# 匯入ERA5資料(NetCDF格式)
nc <- nc_open(ncfilename)

# 顯示所匯入的NetCDF格式資料結構
print(nc)

# 以我目前所知 簡單說明 List 物件 nc 的內容:
# nc資料中有三個軸，四個變數的資料
# 主要包括2019年1到12月，共12個時間點(time  Size:12)的資料，
# 變數資料被放在longitude和latitude所構成的網格位置裡

# 取出ERA5中的氣象資料(資料內容)
# [參數名稱] 參數全名
# [t2m] "2m_temperature"                                
# [d2m] "2m_dewpoint_temperature"                      
# [si10] "10m_wind_speed"                               
# [msdrswrf] "mean_surface_direct_short_wave_radiation_flux"
t2m <- ncvar_get(nc, "t2m") #溫度
d2m <- ncvar_get(nc, "d2m") #露點溫度
ws <- ncvar_get(nc, "si10") #風速
radiation <- ncvar_get(nc, "msdrswrf") #輻射

# 取出ERA5中的位置資料(資料框架)
lon <- ncvar_get(nc, "longitude") #經度
lat <-ncvar_get(nc, "latitude") #緯度
time <- ncvar_get(nc, "time") #時間

# 溫度由 克式溫度 轉 攝氏溫度
temp <- t2m - 273.15
dewp <- d2m - 273.15
# source: 
# https://cds.climate.copernicus.eu/cdsapp#!/dataset/reanalysis-era5-single-levels-monthly-means

# 日期轉成yyyy-mm-dd格式
# time(時間資料)單位為小時，起始時間為1900-01-01 00:00:00.0
time <- as.numeric(time)
dates <- as_datetime(time * 60 * 60, origin = as.Date("1900-01-01", tz = "UTC"))

# 2.3 計算室外WBGT ####

# 建立WBGT_data資料夾輸出計算完的WBGT資料
# dir.create("B:/r/version control/temperature data/WBGT_data")

# 將temp(溫度資料)複製給test，
# 原因: 將計算完的wbgt資料放置與原本變數一樣的經緯度位置裡
test <- temp

# 透過wbgt.Liljegren函數計算室外WBGT後，
# 將各月份WBGT資料，輸出成RData儲存
# 注意事項:
# 因為目前測試是以月平均數值計算，
# 但wbgt.Liljegren函數中dates參數需填入 數值對應的日期，
# 而以月份第一天代替，如2019年1月的氣候資料月平均值，填入2019-01-01
# 故關於wbgt.Liljegren函數中dates參數的設定需再調整

  for (t in seq_along(time)) {
    for (y in seq_along(lat)) {
      for (x in seq_along(lon)) {
        # 取出NetCDF資料中不同經度 緯度 時間點的方法:
        # 以t2m 溫度資料為例，t2m[lon,lat,time]
        # t2m[,,1] 代表第一個時間點所有經緯度的溫度資料
        # t2m[1,2,] 代表 特定位置的12個時間點的資料
        # 特定位置: 第一個經度所對應的第二個緯度的位置，
        # 準確的經緯度數值可透過lon和lat變數取得，
        # 第一個經度為lon[1]:119.27 ，第二個緯度lat[2]:25.44
        WBGT <- wbgt.Liljegren(temp[x, y, t], dewp[x, y, t] , ws[x, y, t] , radiation[x, y, t] , dates[t], lon[x] , lat[y])
        test[x, y, t] <- WBGT$data
        message(x, " , ", y , " , ", t)
      }
    }
    name <- paste0("ERA5_2019_", t)
    filename <- paste0(getwd(),"/WBGT_data/", name, ".RData")
    # 將計算完的WBGT資料指定特定名稱
    assign(name, test[, , t])
    # WBGT資料儲存成RData
    save(list = name , file = filename)
    message("saved ", name)
  }


# 3.繪製WBGT地理分布圖 #####

# 參考下列Geocomputation with R中的方法處理raster(網格數據):
# 1. https://geocompr.robinlovelace.net/spatial-class.html#an-introduction-to-raster
# 2. https://www.neonscience.org/resources/learning-hub/tutorials/extract-values-rasters-r

# 取得網格經緯度資料
ncfilename <- paste0(getwd(),"/ERA5/ERA5_2019_wbgt_var_TW_.nc")
nc <- nc_open(ncfilename)
lat <- ncvar_get(nc, "latitude")
lon <- ncvar_get(nc, "longitude")

# 取得WBGT資料檔案路徑
Datapath <- dir( paste0(getwd(),"/WBGT_data/"), full.names = T, pattern = "TW")

# 讓檔案路徑照建立時間排序
index <- order(file.mtime(Datapath))
Datapath <- Datapath[index]

#月份簡稱
month <- c("Jan.", "Feb.", "Mar.", "Apr.", "May.", "Jun.", "Jul.", "Aug.", 
           "Sep.", "Oct.", "Nov.", "Dec.")

#地理分布圖標題，ex: 2019 Jan.
mName <- paste0("2019 ", month)

#讀入台灣行政區區域圖(shp file)資料
shpfile <- dir(paste0(getwd(),"/shp"), pattern = "shp$", full.names = T)
shpData <- readOGR(shpfile, use_iconv = T, encoding = "UTF-8")

#重新設定台灣行政區區域圖為WGS84經緯度
shpData <- spTransform(shpData, CRS("+init=epsg:4326"))

# function for adding shp file on raster plot
fun <- function() {
  plot(shpData, add=TRUE)
}

# 自動繪製台灣2019年1-12月WBGT地理分布圖
for(t in seq_along(Datapath)){
  
  #匯入各月份的WBGT資料
  n <- load(Datapath[t], verbose = T)
  slice <- get(n)
  # 將各月份的WBGT資料轉換成raster物件
  r <- raster(
    t(slice),
    xmn = min(lon),
    xmx = max(lon),
    ymn = min(lat),
    ymx = max(lat),
    crs = CRS(
      "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs+ towgs84=0,0,0"
    )
  )
  
  # 利用raster::mask將覆蓋海面的raster資料去除
  # source:
  # https://geocompr.robinlovelace.net/geometric-operations.html#raster-cropping
  
  r_ <- mask(r, shpData)
  
  # 將WBGT地理分布圖匯出成dpi為600的tiff檔
  # tiff檔 檔案路徑
  tiffName <- paste0(
    getwd(),
    "/plot/",
    "WBGT_Taiwan_",
    gsub("\\.", "", mName[t]),
    ".tiff"
  )
  # 設定 tiff檔檔案路徑 圖片大小 解析度
  tiff(
    filename = tiffName,
    height = 3600,
    width = 2900,
    units = "px",
    res = 600
  )
  
  # raster 地理分布圖數值區間設定
  # brk 變數: 標準化以比較2019年1到12月的數值差異，所以數值區間較大
  # brk_ 變數: 設定圖例中較為密集數值間距
  brk <- round(seq(8.9,28,length.out = 6),2)
  brk_ <- round(seq(8.9,28,length.out = 20))
  
  # 開始畫圖 ####
  # 利用raster::plot將raster物件繪製成圖，
  plot(
    r_,
    xlab = "longitude", #longitude
    ylab = "latitude", #latitude
    legend = F, #代表不加圖例
    axes = T,
    main = mName[t],
    addfun = fun, #將台灣行政區的線條疊加在raster上
    useRaster = F,
    add = F,
    col = heat.colors(5, 0.9, rev = T), #設定WBGT數值區間代表顏色
    breaks = brk #設定數值切割的區間
  )
  
  plot(
    r_,
    legend.only = TRUE, #代表只單獨加上圖例
    col = heat.colors(5, 0.9, rev = T),
    legend.width = 1.5,
    legend.shrink = 1,
    axis.args = list(
      at = brk_,
      labels = brk_,
      cex.axis = 0.6
    ),
    legend.args = list(
      text = 'monthly average WBGT (°C)',
      side = 4,
      font = 2,
      line = 2.5,
      cex = 0.8
    )
  )
  # plot函數主要參照fields::image.plot的參數設定
  # source:
  # https://www.image.ucar.edu/GSP/Software/Fields/Help/image.plot.html
  
  #結束繪圖，輸出tiff檔
  dev.off()
  
}



