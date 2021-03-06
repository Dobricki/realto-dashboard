
#============================Regularity================================================
#------- BINARY similarity -------------
binarydSimilarity= function(a, b) {
  ab= a*b
  maxWorkDays= max(length(a[a>0]) , length(b[b>0]))
  sim=length(ab[ab>0])/maxWorkDays
  return (round(sim,2))
}
# *********************** 1. WSB *************
getRegularity_WSB= function(events) {
  #------- prepare events file
  events$weekofyear=(events$year - min(events$year))*53+events$weekofyear
  events$weekofyear=events$weekofyear- min(events$weekofyear)
  # events$fullname=paste(events$first_name, events$last_name)
  events$fullname=paste(substr(events$first_name,1,2), '. ', substr(events$last_name,1,1),'. ')
  
  # a=ddply(events, .(user_id,first_name,last_name,role_id,weekofyear), summarize, cnt=length(date))
  # hist(a$weekofyear, breaks=max(a$weekofyear))
  #---------------------- compute weekly profile similarity (excclude inactive weeks from computation ----------------
  user_week_day=ddply(events, .(user_id,fullname,role_id,weekofyear,dyofweek), summarize, Study.time=length(unique(hourofday)))
  users=sort(unique(user_week_day$fullname))
  users_WSB= data.frame(fullname=users, WSB=0,activeWeeks=0)
  weeksCount=max(user_week_day$weekofyear)
  for (u in users){
    #---- 1. build weekly profile
    currentUserActs= filter(user_week_day,fullname==u)
    weeks_profile=matrix(0, nrow = weeksCount, ncol = 7)
    for( w in 0:weeksCount)
      for( d in 1:7 )
      {
        a=filter(currentUserActs,weekofyear==w, dyofweek==d)
        if(nrow(a)>0)
          weeks_profile[w,d] = a$Study.time
      }
    #----- 2. compute pairwise weekly similarity
    BIN_sumSimilarity=NULL; # JSD_sumSimilarity=0;  CHI_sumSimilarity=0;
    activeWeeksCount=0
    for(i in 1:(weeksCount-1))
    {
      if (Norm(weeks_profile[i,], p = 2)!=0) activeWeeksCount=activeWeeksCount+1;
      for (j in (i+1):weeksCount)
      {
        if (Norm(weeks_profile[i,], p = 2)*Norm(weeks_profile[j,], p = 2)!=0) 
        {       
          curSim=binarydSimilarity(weeks_profile[i,],weeks_profile[j,] )
          BIN_sumSimilarity = c(BIN_sumSimilarity ,curSim )
          # print(paste0(i,'    ', j, '   --- ' , round(curSim,2)))
        }
      }
    }
    #---- 3. add average to users
    # print(paste0(u,'    ' ,round(mean(BIN_sumSimilarity),2), '      weeks: ', activeWeeksCount))
    users_WSB[which(users_WSB$fullname==u),2]=round(mean(BIN_sumSimilarity),2)
    users_WSB[which(users_WSB$fullname==u),3]=activeWeeksCount
  }
  #------ multiply computed WSB s by ratio of active weeks
  second_max=sort(users_WSB$activeWeeks,decreasing = T)[2]
  users_WSB$weekRatio=users_WSB$activeWeeks/second_max; 
  users_WSB[which(users_WSB$weekRatio>1), 'weekRatio']=1
  users_WSB$WSB_2=round(users_WSB$WSB*users_WSB$weekRatio,2)
  # ----- 4 merge computed values
  user_week_day=merge(user_week_day,users_WSB)
  
  ######## boxplot of class average
  apprentices=filter(user_week_day,role_id=='apprentice')$fullname
  apprentices_reg=filter(users_WSB,fullname %in% apprentices)
  
  m=round(mean(apprentices_reg$WSB_2),2); sd=round (sd((apprentices_reg$WSB_2)),2)
  boxplot_wsb_flow=ggplot(apprentices_reg, aes(x='WSB', y=WSB_2))+geom_boxplot(fill='springgreen4',alpha=0.7)+theme_bw()+
    scale_y_continuous(name = "Weekly Similarity Binary (WSB)",limits=c(0, max(0.5,max(apprentices_reg$WSB_2))))+
    labs(x ="", y = "WSB", title= paste0('Apprentices overview \n m=',m, '   sd=', sd))+
    theme(text = element_text(size=15), axis.text.x = element_text(angle = 0, hjust = 0.5),
          plot.title = element_text(hjust = 0.5),panel.grid.minor = element_blank())
  
  #------- 5 plot weeks profile
  maxVal=max(user_week_day$Study.time)
  cellsCol='red'
  daylabels=c('Mon','Tue', 'Wed','Thu','Fri','Sat','Sun')
  ######## weeks profile
  plot_profiles=ggplot(user_week_day, aes(dyofweek, weekofyear)) +theme_bw()+
    geom_tile(aes(fill = Study.time),colour = "red" )+
    scale_fill_gradient(limits=c(0,maxVal),low = "white",high = cellsCol, na.value = "dimgrey")+
    # scale_y_continuous(limits = c(0.5, 10.5), breaks=seq(1,weeksCount,1))+
    scale_x_continuous(limits=c(0.5,7.5), breaks=seq(1,7,1), labels = daylabels)+
    theme(text = element_text(size=15), axis.text.x = element_text(angle = 0, hjust = 0.5), 
          legend.position ="right",strip.background = element_rect( fill='papayawhip'),panel.grid.major =element_blank())+
    labs(x ="Week day", y = "Week", title='')+ facet_wrap(~paste(role_id, ': ',fullname )+paste('  WSB:', WSB_2 ), ncol=4)
  print(plot_profiles)
  
  
  # p=grid.arrange(plot_profiles,boxplot_wsb_flow, ncol=2, widths=c(80,20))
  p=grid.arrange(plot_profiles,boxplot_wsb_flow,
                 layout_matrix = rbind(c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2)))
  
  return(p)
}
# *********************** 2. CWD: Certain Week day regularity *************
#------------------ entropy function
H <- function(v) {
  v <- v[v > 0]
  return(sum(-v * log(v)))
}
getRegularity_peakWeekDay= function(events) {
  daylabels=c('Mon','Tue', 'Wed','Thu','Fri','Sat','Sun')
  #------- prepare events file
  events$weekofyear=(events$year - min(events$year))*53+events$weekofyear
  events$weekofyear=events$weekofyear- min(events$weekofyear)
  #       events$fullname=paste(events$first_name, events$last_name)
  events$fullname=paste(substr(events$first_name,1,2), '. ', substr(events$last_name,1,1),'. ')
  
  #----------- weekly histograms -------------------
  user_weekday_count=ddply(events, .(user_id,fullname,role_id,dyofweek), summarize, countOfWeeks=length(unique(weekofyear)))
  users=sort(unique(user_weekday_count$fullname))
  users_CWD= data.frame(fullname=users, CWD=0)
  for (u in users){
    currentUserHist=filter(user_weekday_count,fullname==u)
    W_d=currentUserHist[order(currentUserHist$dyofweek),'countOfWeeks']
    max_val_in_WeekDay=max(W_d)
    W_d_normalized=W_d / sum(W_d)
    (E_w=H(W_d_normalized))
    CWD= (log(7) - E_w) * max_val_in_WeekDay
    users_CWD[which(users_CWD$fullname==u),2]=round(CWD,2)
  }
  #---merge
  user_weekday_count=merge(user_weekday_count,users_CWD)
  
  ######### boxplot of class average  for CWD
  apprentices=filter(user_weekday_count,role_id=='apprentice')$fullname
  apprentices_reg=filter(users_CWD,fullname %in% apprentices)
  m=round(mean(apprentices_reg$CWD),2); sd=round (sd((apprentices_reg$CWD)),2)
  boxplot_CWD_flow=
    ggplot(apprentices_reg, aes(x='CWD', y=CWD))+geom_boxplot(fill='springgreen4',alpha=0.7)+theme_bw()+
    scale_y_continuous(name = "Certain Week Day (CWD)")+
    labs(x ="", y = "CWD", title= paste0('Flow overview \n m=',m, '   sd=', sd))+
    theme(text = element_text(size=15), axis.text.x = element_text(angle = 0, hjust = 0.5),
          plot.title = element_text(hjust = 0.5),  panel.grid.minor = element_blank())      
  ######### weekly histograms and CWD for each user
  weeklyHistogramPlots=
    ggplot(data=user_weekday_count, aes(x=dyofweek,y=countOfWeeks))+theme_bw()+
    geom_bar(stat="identity",fill='blue')+
    # scale_y_continuous(limits = c(0, 10), breaks=seq(0,weeksCount,2))+
    scale_x_continuous(limits=c(0.5,7.5),breaks=seq(1,7,1), labels = daylabels)+
    labs(title="Individual weekly histograms",   x ="Week day", y = "Count of weeks",  title= 'Weekly histograms and CWD regularity') +
    theme(text = element_text(size=13), axis.text.x = element_text(angle = 0, hjust = 0.5),
          strip.background = element_rect( fill='papayawhip'),
          panel.grid.minor = element_blank(),plot.title = element_text(hjust = 0.5))+
    facet_wrap(~paste(role_id, ': ',fullname )+paste('  CWD:', CWD ), ncol=4)
  ######### average weekly histograms and CWD apps vs tacher
  roles_cnt= ddply(user_weekday_count, .(role_id), summarize, role_cnt=length(unique(fullname)))
  average_weekDay_roles= ddply(user_weekday_count, .(role_id,dyofweek), summarise,sumcountOfWeeks=sum(countOfWeeks))
  average_weekDay_roles=merge(average_weekDay_roles,roles_cnt)
  average_weekDay_roles$avgcountOfWeeks=average_weekDay_roles$sumcountOfWeeks/average_weekDay_roles$role_cnt
  
  appsAverage =  
    ggplot(data=filter(average_weekDay_roles,role_id=='apprentice'), aes(x=dyofweek,y=avgcountOfWeeks))+theme_bw()+
    geom_bar(stat="identity",fill='blue')+
    scale_x_continuous(limits=c(0.5,7.5),breaks=seq(1,7,1), labels = daylabels)+
    labs(title="Average weekly histograms",   x ="Week day", y = "Average count of weeks",  title= 'Weekly histograms and CWD regularity') +
    theme(text = element_text(size=15), axis.text.x = element_text(angle = 0, hjust = 0.5),
          strip.background = element_rect( fill='papayawhip'),
          panel.grid.minor = element_blank(),plot.title = element_text(hjust = 0.5))+
    facet_wrap(~paste(role_id), scales = "free_y",ncol=4)
  
  otherRolesAveage=
    ggplot(data=filter(average_weekDay_roles,role_id!='apprentice'), aes(x=dyofweek,y=avgcountOfWeeks))+theme_bw()+
    geom_bar(stat="identity",fill='blue')+
    scale_x_continuous(limits=c(0.5,7.5),breaks=seq(1,7,1), labels = daylabels)+
    labs(title="Average weekly histograms",   x ="Week day", y = "Average count of weeks",  title= 'Weekly histograms and CWD regularity') +
    theme(text = element_text(size=15), axis.text.x = element_text(angle = 0, hjust = 0.5),
          strip.background = element_rect( fill='papayawhip'),
          panel.grid.minor = element_blank(),plot.title = element_text(hjust = 0.5))+
    facet_wrap(~paste(role_id), scales = "free_y",ncol=4)
  
  
  #         weeklyHistogramAppsandTeacher= 
  #         ggplot(data=average_weekDay_roles, aes(x=dyofweek,y=avgcountOfWeeks))+theme_bw()+
  #                 geom_bar(stat="identity",fill='blue')+
  #                 # scale_y_continuous(limits = c(0, 10), breaks=seq(0,weeksCount,2))+
  #                 scale_x_continuous(limits=c(0.5,7.5),breaks=seq(1,7,1), labels = daylabels)+
  #                 labs(title="Average weekly histograms",   x ="Week day", y = "Average count of weeks",  title= 'Weekly histograms and CWD regularity') +
  #                 theme(text = element_text(size=15), axis.text.x = element_text(angle = 0, hjust = 0.5),
  #                       strip.background = element_rect( fill='papayawhip'),
  #                       panel.grid.minor = element_blank(),plot.title = element_text(hjust = 0.5))+
  #                 facet_wrap(~paste(role_id), scales = "free_y",ncol=4)
  #       
  #------ merge plots --------
  # p=grid.arrange(weeklyHistogramPlots,boxplot_CWD_flow, weeklyHistogramAppsandTeacher, 
  # layout_matrix = rbind(c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2), c(3,3,3,3),c(3,3,3,3),c(3,3,3,3)))
  p=grid.arrange(weeklyHistogramPlots,boxplot_CWD_flow, appsAverage ,otherRolesAveage, 
                 layout_matrix = rbind(c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2), c(3,3,4,4),c(3,3,4,4),c(3,3,4,4)))
  
  return(p)
}


# *********************** 3. CDH: Certain week day regularity *************
getRegularity_peakDayHour= function(events) {
  # daylabels=c('Mon','Tue', 'Wed','Thu','Fri','Sat','Sun')
  #------- prepare events file
  events$weekofyear=(events$year - min(events$year))*53+events$weekofyear
  events$weekofyear=events$weekofyear- min(events$weekofyear)
  events$dayofyear=(events$year - min(events$year))*365+events$dayofyear
  # events$fullname=paste(events$first_name, events$last_name)
  events$fullname=paste(substr(events$first_name,1,2), '. ', substr(events$last_name,1,1),'. ')
  
  #----------- daily histograms -------------------
  user_dayhour_count=ddply(events, .(user_id,fullname,role_id,hourofday), summarize, countOfDays=length(unique(dayofyear)))
  users=sort(unique(user_dayhour_count$fullname))
  users_CDH= data.frame(fullname=users, CDH=0)
  for (u in users){
    # u=users[1]
    currentUserHist=filter(user_dayhour_count,fullname==u)
    D_h=rep(0, 24)
    D_h[currentUserHist$hourofday]=currentUserHist$countOfDays
    max_val_in_dayHour=max(D_h)
    D_h_normalized=D_h / sum(D_h)
    (E_d=H(D_h_normalized))
    CDH= (log(24) - E_d) * max_val_in_dayHour
    users_CDH[which(users_CDH$fullname==u),2]=round(CDH,2)
  }
  
  #---merge
  user_dayhour_count=merge(user_dayhour_count,users_CDH)
  
  ######### boxplot of class average  for CDH
  apprentices=filter(user_dayhour_count,role_id=='apprentice')$fullname
  apprentices_reg=filter(users_CDH,fullname %in% apprentices)
  m=round(mean(apprentices_reg$CDH),2); sd=round (sd((apprentices_reg$CDH)),2)
  boxplot_CDH_flow=
    ggplot(apprentices_reg, aes(x='CDH', y=CDH))+geom_boxplot(fill='springgreen4',alpha=0.7)+theme_bw()+
    scale_y_continuous(name = "Certain Day Hour (CDH)")+
    labs(x ="", y = "CDH", title= paste0('Apprentices overview \n m=',m, '   sd=', sd))+
    theme(text = element_text(size=15), axis.text.x = element_text(angle = 0, hjust = 0.5),
          plot.title = element_text(hjust = 0.5),  panel.grid.minor = element_blank())      
  ######### daily histograms and CDH for each user
  dailyHistogramPlots=
    ggplot(data=user_dayhour_count, aes(x=hourofday,y=countOfDays))+theme_bw()+
    geom_bar(stat="identity",fill='blue')+
    # scale_y_continuous(limits = c(0, 10), breaks=seq(0,weeksCount,2))+
    scale_x_continuous(limits=c(-0.5,23.5), breaks=seq(0,23,3), labels = seq(0,23,3))+
    labs(title="Individual daily histograms",   x="Day hour", y = "Count of days" ,  title= 'Weekly histograms and CWD regularity') +
    theme(text = element_text(size=13), axis.text.x = element_text(angle = 0, hjust = 0.5),
          strip.background = element_rect( fill='papayawhip'),
          panel.grid.minor = element_blank(),plot.title = element_text(hjust = 0.5))+
    facet_wrap(~paste(role_id, ': ',fullname )+paste('  CDH:', CDH ), ncol=4)
  
  ######### average daily histograms and CDH apps vs tacher
  # average_dayhour_roles= ddply(user_dayhour_count, .(role_id,hourofday), summarise, avgCountOfDays=mean(countOfDays))
  roles_cnt= ddply(user_dayhour_count, .(role_id), summarize, role_cnt=length(unique(fullname)))
  average_dayhour_roles= ddply(user_dayhour_count, .(role_id,hourofday), summarise, sumCountOfDays=sum(countOfDays), avgCountOfDays=(sumCountOfDays))
  average_dayhour_roles=merge(average_dayhour_roles,roles_cnt)
  average_dayhour_roles$avgCountOfDays=average_dayhour_roles$sumCountOfDays/average_dayhour_roles$role_cnt
  
  appsAverage=
    ggplot(data=filter(average_dayhour_roles,role_id=='apprentice'), aes(x=hourofday,y=avgCountOfDays))+theme_bw()+
    geom_bar(stat="identity",fill='blue')+
    # scale_y_continuous(limits = c(0, 10), breaks=seq(0,weeksCount,2))+
    scale_x_continuous(limits=c(-0.5,23.5), breaks=seq(0,23,1), labels = seq(0,23,1))+
    labs(title="Average daily histogram",   x="Day hour", y = "Average count of days" ) +
    theme(text = element_text(size=15), axis.text.x = element_text(angle = 0, hjust = 0.5),
          strip.background = element_rect( fill='papayawhip'),
          panel.grid.minor = element_blank(),plot.title = element_text(hjust = 0.5))+
    facet_wrap(~paste(role_id),scales = ("free"), ncol=4)
  otherRolesAveage =
    ggplot(data=filter(average_dayhour_roles,role_id!='apprentice'), aes(x=hourofday,y=avgCountOfDays))+theme_bw()+
    geom_bar(stat="identity",fill='blue')+
    # scale_y_continuous(limits = c(0, 10), breaks=seq(0,weeksCount,2))+
    scale_x_continuous(limits=c(-0.5,23.5), breaks=seq(0,23,1), labels = seq(0,23,1))+
    labs(title="Average daily histogram",   x="Day hour", y = "Average count of days" ) +
    theme(text = element_text(size=15), axis.text.x = element_text(angle = 0, hjust = 0.5),
          strip.background = element_rect( fill='papayawhip'),
          panel.grid.minor = element_blank(),plot.title = element_text(hjust = 0.5))+
    facet_wrap(~paste(role_id),scales = ("free"), ncol=4)
  
  #       dailyHistogramAppsandTeacher=ggplot(data=average_dayhour_roles, aes(x=hourofday,y=avgCountOfDays))+theme_bw()+
  #         geom_bar(stat="identity",fill='blue')+
  #         # scale_y_continuous(limits = c(0, 10), breaks=seq(0,weeksCount,2))+
  #         scale_x_continuous(limits=c(-0.5,23.5), breaks=seq(0,23,1), labels = seq(0,23,1))+
  #         labs(title="Average daily histogram",   x="Day hour", y = "Average count of days" ) +
  #         theme(text = element_text(size=15), axis.text.x = element_text(angle = 0, hjust = 0.5),
  #               strip.background = element_rect( fill='papayawhip'),
  #               panel.grid.minor = element_blank(),plot.title = element_text(hjust = 0.5))+
  #         facet_wrap(~paste(role_id),scales = ("free"), ncol=4)
  #       
  
  #------ merge plots --------
  # p=grid.arrange(dailyHistogramPlots,boxplot_CDH_flow, dailyHistogramAppsandTeacher, 
  # layout_matrix = rbind(c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2), c(1,1,1,2),c(3,3,3,3),c(3,3,3,3),c(3,3,3,3)))
  
  p=grid.arrange(dailyHistogramPlots, boxplot_CDH_flow,  appsAverage ,otherRolesAveage, 
                 layout_matrix = rbind(c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2),c(1,1,1,2), c(3,3,4,4),c(3,3,4,4),c(3,3,4,4)))
  
  
}