fun.up_sort<-function(x,doindex=T){
  n<-length(x)
  big<-max(x)
  i=1
  y<-x[i]
  ans=y
  ans_index=i
  while(y!=big){
    j<-which(x>y)
    index<-j[which(j>i)][1]
    y<-x[index]
    i=index
    ans=c(ans,y)
    ans_index=c(ans_index,i)
  }
  ifelse(doindex,return(ans_index),return(ans))
}