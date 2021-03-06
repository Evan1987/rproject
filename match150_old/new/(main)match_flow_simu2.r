library(data.table)
library(magrittr)
library(dplyr)
library(tibble)
source('~/rstudio/match150/(fun)fun.asset_deadline.r', encoding = 'UTF-8')
source('~/rstudio/match150/(fun)fun.time_seq.r', encoding = 'UTF-8')
source('~/rstudio/match150/new/(fun)fun.cumminus.r', encoding = 'UTF-8')
source('~/rstudio/match150/(fun)fun.redeem_select_asset.r', encoding = 'UTF-8')
source('~/rstudio/match150/(fun)match_temp2.r', encoding = 'UTF-8', echo=TRUE)
source('~/rstudio/match150/(fun)match_time_flow_evaluation.r', encoding = 'UTF-8', echo=TRUE)
path<-"F:/Project/20170315资产匹配穿透150人调研/时间流模拟/"
n=as.integer(150)

############################## 0.模拟数据源加载 #################################
# 0.0时间流序列时间轴
time_seq<-fun.time_seq(Dseq = seq.Date(from = as.Date("2017-03-15"),to = as.Date("2017-03-22"),by = "day"),
                       HMSseq = 7:22)%>%c(.,as.POSIXct("2017-03-15 00:00:00"))%>%sort(.)
# 0.1匹配起点资产状态
asset_initial<-fread(paste0(path,"asset_list.csv"))%>%tbl_df(.)%>%select(.,-avg_avail_amount)
# 0.2匹配起点资产匹配信息
match_record_initial<-fread(paste0(path,"match_record.csv"))%>%tbl_df(.)%>%
  mutate(.,log_time=as.POSIXct("2017-03-14 23:59:59"))%>%
  mutate(.,type=case_when(.$type=="regular"~2,.$type=="tPlus"~1,.$type=="current"~0,T~as.double(NA)))
#0.3资产整体数据
asset<-fread(paste0(path,"asset_simu_data.csv"))%>%tbl_df(.)%>%
  mutate(.,create_time=as.POSIXct(create_time),end_time=as.POSIXct(end_time))%>%
  rename(.,amount=corpusamount)

# 0.4匹配起点用户资金序列状态
user_list<-fread(paste0(path,"user_list.csv"))%>%
  .[,log_time:=as.POSIXct("2017-03-14 23:59:59")]%>%tbl_df(.)

regular<-select_(user_list,.dots = c("userid",
                                     "unmatched_premium"="unmatched_regular_premium",
                                     "log_time"))%>%
  filter(.,unmatched_premium>0)%>%
  mutate(.,unmatched_premium=as.double(unmatched_premium))

tPlus<-select_(user_list,.dots = c("userid",
                                   "unmatched_premium"="unmatched_tPlus_premium",
                                   "log_time"))%>%
  filter(.,unmatched_premium>0)%>%
  mutate(.,unmatched_premium=as.double(unmatched_premium))

current<-select_(user_list,.dots = c("userid",
                                     "unmatched_premium"="unmatched_current_premium",
                                     "log_time"))%>%
  filter(.,unmatched_premium>0)%>%
  mutate(.,unmatched_premium=as.double(unmatched_premium))

# 0.5资产入库时间流整体
in_asset<-tbl_df(asset)%>%
  rename_(.,.dots=setNames("amount","unmatched_amount"))%>%
  filter(.,create_time>=as.POSIXct("2017-03-15")&unmatched_amount>0)%>%{
    fun.asset_deadline<-Vectorize(fun.asset_deadline)
    mutate(.,deadline=fun.asset_deadline(create_time)%>%as.POSIXct(.,origin="1970-01-01 00:00:00"),
           avail_num=n,
           issettled=0,
           settled_time=as.POSIXct(NA))}
# 0.6资产出库时间流整体
out_asset<-tbl_df(asset)%>%
  rename_(.,.dots=setNames("amount","unmatched_amount"))%>%
  filter(.,end_time<=as.POSIXct("2017-03-22")&unmatched_amount>0)

# 0.7投资时间流整体
invest<-fread(paste0(path,"invest_simu_data.csv"))%>%tbl_df(.)%>%
  mutate(.,create_time=as.POSIXct(create_time))

# 0.8赎回时间流整体
redeem<-fread(paste0(path,"redeem_simu_data.csv"))%>%tbl_df(.)%>%
  mutate(.,create_time=as.POSIXct(create_time))

# 0.9循环初始值
#----当前匹配信息表
match_status_now<-copy(match_record_initial)
#----当前资产信息表
asset_now<-copy(asset_initial)%>%
  left_join(.,select(asset,id,create_time,end_time),by=c("id"="id"))%>%
  filter(.,end_time>=as.POSIXct("2017-03-14 23:59:59"))%>%
  {
    fun.asset_deadline<-Vectorize(fun.asset_deadline)
    mutate(.,deadline=fun.asset_deadline(create_time)%>%as.POSIXct(.,origin="1970-01-01 00:00:00"),
           issettled=1,
           settled_time=create_time,
           unmatched_amount=as.double(unmatched_amount),
           amount=as.double(amount))
  }

#----当前定期序列
regular_now<-copy(regular)%>%mutate(.,remark=as.integer(NA))
#----当前T+N序列
tPlus_now<-copy(tPlus)%>%mutate(.,remark=as.integer(NA))
#----当前活期序列
current_now<-copy(current)%>%mutate(.,remark=as.integer(NA))

#----赎回记录总表，先创建空的
redeem_record<-data.table(id=0,
                          userid="0",
                          create_time=as.POSIXct("2017-03-23 0:00:00"),
                          amount=1000,
                          type=1,
                          status=1,
                          update_time=as.POSIXct("2017-03-24 0:00:00"))%>%.[-1,]%>%tbl_df(.)
#----赎回冲抵锁定总表，先创建空的
redeem_forzen_now<-data.table()
#----赎回资产总表，先创建空的
redeem_asset<-data.table()%>%tbl_df(.)

#--额外投资队列，先创建空的
extra_invest<-data.table(id=1,
                         redeemID=0,
                         userid="0",
                         create_time=as.POSIXct("2017-03-23 0:00:00"),
                         unmatched_premium=1000,
                         type=1,
                         isFrozen=0)%>%.[-1,]%>%tbl_df(.)


############################## 1.时间流验证 #################################
# asset_status_log<-data.table()%>%tbl_df(.)
# redeem_asset_log<-data.table()%>%tbl_df(.)
# redeem_asset_snap_log<-data.table()%>%tbl_df(.)
# match_status_log<-data.table()%>%tbl_df(.)
# redeem_record_log<-data.table()%>%tbl_df(.)
# redeem_status_log<-data.table()%>%tbl_df(.)
# asset_now_log<-data.table()%>%tbl_df(.)
# end_for=length(time_seq)-1
# for(index in 1:end_for){
#   result<-match_time_flow_evaluation(time_seq = time_seq,
#                                      index = index,
#                                      in_asset = in_asset,
#                                      out_asset = out_asset,
#                                      invest = invest,
#                                      redeem = redeem,
#                                      redeem_record = redeem_record,
#                                      redeem_log = redeem_log,
#                                      redeem_asset=redeem_asset,
#                                      asset_now = asset_now,
#                                      match_status_now = match_status_now,
#                                      regular_now = regular_now,
#                                      tPlus_now = tPlus_now,
#                                      current_now = current_now,
#                                      n = n)
#   
#   redeem_record<-result$redeem_record
#   redeem_log<-result$redeem_log
#   redeem_asset<-result$redeem_asset
#   asset_now<-result$asset_now
#   match_status_now<-result$match_status_now
#   regular_now<-result$regular_now
#   tPlus_now<-result$tPlus_now
#   current_now<-result$current_now
#   redeem_status<-result$redeem_status
#   redeem_asset_snap<-result$redeem_asset_snap
#   
#   asset_status_log<-rbind(asset_status_log,copy(result$asset_status_summary)%>%mutate(.,label=index))
#   redeem_asset_log<-rbind(redeem_asset_log,copy(redeem_asset)%>%mutate(.,label=index))
#   redeem_record_log<-rbind(redeem_record_log,copy(redeem_record)%>%mutate(.,label=index))
#   asset_now_log<-rbind(asset_now_log,copy(asset_now)%>%mutate(.,label=index))
#   redeem_status_log<-rbind(redeem_status_log,copy(redeem_status)%>%mutate(.,label=index))
#   redeem_asset_snap_log<-rbind(redeem_asset_snap_log,copy(redeem_asset_snap)%>%mutate(.,label=index))
# }

