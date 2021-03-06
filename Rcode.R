library(MASS)
library(sm)
library(gplots)
library(lme4)
library(dplyr)
rm(list=ls())

#Game contains each game's characteristics, pbp contains each play
game<-read.csv("/Users/mlopez1/Downloads/csv_json_00-14 (1)/csv/GAME.csv")
pbp<-read.csv("/Users/mlopez1/Downloads/csv_json_00-14 (1)/csv/PBP.csv")

#Eliminate special teams plays
pbp<-filter(pbp,type=="RUSH"|type=="PASS")


#Game conditions
BadW<-c("Thunderstorms","Light Rain","Light Snow","Rain","Snow","Flurries")
game$Weather<-"Okay"
game[game$cond%in%BadW,]$Weather<-"Risky"
game[game$cond=="Dome"|game$cond=="Closed Roof"|game$cond=="Covered Roof",]$Weather<-"Dome_ClosedRoof"


#Merge the game data to pbp
pbp<-merge(pbp,game,by.x="gid",by.y="gid")

#Is home team on offense? 
pbp$OffHome<-pbp$off==pbp$h

#2007 and beyond
pbp$Recent<-pbp$seas>=2007

#get rid of kneel downs
temp<-filter(pbp,kne=="Y",Recent=="TRUE")
barplot(table(temp$off),col=c(rep("grey",18),"blue",rep("grey",14)),las=2,
        main= "Total Kneel Downs, 2007-2015")

#Spikes exist, too
temp<-filter(pbp,spk=="Y")
barplot(table(temp$off),col=c(rep("red",18),"blue",rep("red",14)),
        main= "Spikes")

#Interceptions
pbp$Intercepted<-pbp$int!=""

#DownDistance
pbp$DownDistance<-"First"
pbp[pbp$dwn==2&pbp$ytg<=3,]$DownDistance<-"SecondShort"
pbp[pbp$dwn==2&pbp$ytg>3,]$DownDistance<-"SecondMed"
pbp[pbp$dwn==2&pbp$ytg>6,]$DownDistance<-"SecondLong"
pbp[pbp$dwn==3&pbp$ytg<=3,]$DownDistance<-"ThirdFourthShort"
pbp[pbp$dwn==3&pbp$ytg>3,]$DownDistance<-"ThirdFourthMed"
pbp[pbp$dwn==3&pbp$ytg>6,]$DownDistance<-"ThirdFourthLong"
pbp[pbp$dwn==4&pbp$ytg<=3,]$DownDistance<-"ThirdFourthShort"
pbp[pbp$dwn==4&pbp$ytg>3,]$DownDistance<-"ThirdFourthMed"
pbp[pbp$dwn==4&pbp$ytg>6,]$DownDistance<-"ThirdFourthLong"


#Fumble?
pbp$Fumble10<-pbp$fum!=""

#Game Score (by possessions and time)
pbp$Score<-"TIED"
pbp[pbp$ptso-pbp$ptsd>0,]$Score<-"Offense up 1 Possession"
pbp[pbp$ptso-pbp$ptsd>8,]$Score<-"Offense up 2 Possessions"
pbp[pbp$ptso-pbp$ptsd>16,]$Score<-"Offense up 3+ Possessions"
pbp[pbp$ptsd-pbp$ptso>0,]$Score<-"Offense down 1 Possession"
pbp[pbp$ptsd-pbp$ptso>8,]$Score<-"Offense down 2 Possessions"
pbp[pbp$ptsd-pbp$ptso>16,]$Score<-"Offense down 3+ Possessions"
aggregate(Fumble10~Score,FUN="mean",data=pbp)

aggregate(Fumble10~Score=="Offense up 3+ Possessions",FUN="mean",data=pbp)

temp<-filter(pbp,Score=="Offense up 3+ Possessions",Recent=="TRUE")
barplot(table(temp$off),col=c(rep("grey",18),"blue",rep("grey",14)),las=2,
       main= "Plays when ahead by 3+ possessions, 2007-2015")

#Rid of the garbage: spikes, kneel downs, interceptions all dropped here
pbp<-filter(pbp,spk!="Y"&kne!="Y"&Intercepted=="FALSE")

#Game Minute? Matters most at end of game, half
pbp<-filter(pbp,qtr<5)  #Q1-Q4 only, as to make sure we account for game minute
pbp$GameMin<-(15-as.numeric(as.character(pbp$min)))+15*(as.numeric(as.character(pbp$qtr-1)))

#final minutes of the half/game?
pbp$FinalMins<-pbp$GameMin==28|pbp$GameMin==29|pbp$GameMin==30|pbp$GameMin>=57

#Game's point spread, offensive team - defensive team
pbp$spread<-pbp$sprv
pbp[pbp$OffHome=="FALSE",]$spread<--1*pbp[pbp$OffHome=="FALSE",]$spread


#By goal-to-go on the field
pbp$GoaltoGo<-as.factor(pbp$yfog>90)
dat<-table(pbp$off,pbp$GoaltoGo)
barplot(dat[,2],col=c(rep("grey",18),"blue",rep("grey",14)),las=2,
        main= "Goal to go plays, 2007-2015")

#Separate by play type
aggregate(Fumble10~dir,data=pbp,FUN="mean")
aggregate(Fumble10~loc,data=pbp,FUN="mean")

pbp$playcall<-"Unknown Pass"
pbp[pbp$dir=="MD",]$playcall<-"Run Middle"
pbp[pbp$dir=="LG"|pbp$dir=="LT"|pbp$dir=="LE",]$playcall<-"Run Left"
pbp[pbp$dir=="RG"|pbp$dir=="RT"|pbp$dir=="RE",]$playcall<-"Run Right"
pbp[pbp$loc=="SL"|pbp$loc=="SR",]$playcall<-"Short Pass, sideline"
pbp[pbp$loc=="DM"|pbp$loc=="SM",]$playcall<-"Middle Pass"
pbp[pbp$loc=="DR"|pbp$loc=="DL",]$playcall<-"Deep Pass, sideline"

#Did the game occur in the playoffs?
pbp$Playoffs<-(pbp$week>17)


#Include recent plays only
pbp<-filter(pbp,Recent=="TRUE")

#Rescale OU
pbp<-mutate(pbp,ou2=(ou-mean(game$ou))/sd(game$ou))

#Naive fixed effect model
summary(glm(Fumble10~Score+playcall+FinalMins+Playoffs+Weather+GoaltoGo+OffHome 
+ DownDistance+sg+nh+ou+spread+off,family=binomial(),data=filter(pbp,type=="RUSH")))

#Passing plays, GLMM

fit.pass<-glmer(Fumble10~Score+playcall+FinalMins+Playoffs+Weather+GoaltoGo+OffHome+
        DownDistance+sg+nh+ou2+spread+(1|off)+(1|def),data=filter(pbp,type=="PASS"),
        control=glmerControl(optCtrl=list(maxfun=300)),
      verbose=TRUE,family=binomial())
summary(fit.pass)

#Running plays, GLMM
fit.rush<-glmer(Fumble10~Score+playcall+FinalMins+Playoffs+Weather+GoaltoGo+OffHome+
        DownDistance+sg+nh+ou2+spread+(1|off)+(1|def), data=filter(pbp,type=="RUSH"),
        control=glmerControl(optCtrl=list(maxfun=300)),verbose=TRUE,family=binomial())
summary(fit.rush)

#Graph the random effects

randoms<-ranef(fit.rush, condVar = TRUE)$off
qq <- attr(ranef(fit.rush, condVar = TRUE)[[1]], "postVar") #The [[1]] is the offensive RE
rand.interc<-randoms[,1]
df<-data.frame(Intercepts=randoms[,1],
      sd.interc=2*sqrt(qq[,,1:length(qq)]),
      lev.names=rownames(randoms))
df$lev.names<-factor(df$lev.names,levels=df$lev.names[order(df$Intercepts)])
df<-df[order(df$Intercepts),]
library(ggplot2)
p<- ggplot(df,aes(lev.names,Intercepts,shape=lev.names)) + geom_hline(yintercept=0) +
  geom_errorbar(aes(ymin=Intercepts-sd.interc, ymax=Intercepts+sd.interc), 
       width=0,color="black") + geom_point(aes(size=2),pch=16) + 
  ggtitle("Random effects, rushing plays")+
  guides(size=FALSE,shape=FALSE) +theme_bw() + xlab("Teams") + ylab("") + coord_flip()
print(p)
ggsave(plot=p, height=8.6, width=5.47, filename="Lopez-fumbles.pdf",
      useDingbats=FALSE)
