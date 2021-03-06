library(data.table)
library(magrittr)
library(readr)
library(dplyr)
source('~/rstudio/!custom/(fun)colname_treat.R')
source('~/rstudio/!custom/(fun)fun.elbow_point.r', encoding = 'UTF-8')
path="F:/Project/20170419用户流失风险预警模型/"

# rawdata<-fread(paste0(path,"rawdata.csv"))
# rawdata<-colname_treat(rawdata)
# rawdata[,reg_time:=as.POSIXct(reg_time)]
# 
# rawdata[open_time=='null',":="(open_time=NA,invest1st_time=NA)]
# rawdata[invest1st_time=='null',invest1st_time:=NA]
# write.csv(rawdata,paste0(path,"mydata.csv"),row.names = F)

reg_to_open<-read_csv(paste0(path,"reg_to_invest_data.csv"),locale = locale(encoding = "GBK"))%>%
  select(.,-invest1st_time)%>%
  mutate(.,wait_time=ifelse(is.na(open_time),Inf,difftime(open_time,reg_time,units="days")%>%as.numeric(.)))
  

reg_to_open<-as.data.table(reg_to_open)
quantile(reg_to_open[!is.na(open_time),]$wait_time,probs = seq(0,1,0.1))

valid_data<-reg_to_open[!is.na(open_time),]
num=nrow(valid_data)
dayspan<-seq(0.1,30,0.1)
result<-data.table()
#对这个问题，无论怎么选天数阈值，tpr都是1，而fpr则随着天数阈值增加而减小，因此需选取肘点
for(i in dayspan){
  fpr = nrow(valid_data[wait_time>i,])/num
  temp=data.table(wait_time=i,fpr=fpr)
  result<-rbind(result,temp)
}

elbow_point=fun.elbow_point(result$wait_time,result$fpr,doplot = T)

