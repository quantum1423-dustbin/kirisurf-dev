#lang racket

(define LANG (read-line (open-input-file "./lang.txt")))

(define (l10n key)
  (match LANG
    ["en"
     (match key
       ['version "2.0.0"]
       ['name "Kirisurf"]
       ['status "Status"]
       ['details "Technical details"]
       ['settings "Settings"]
       ['reportbug "Report a bug"]
       
       ['dlspeed "Current speed:"]
       ['totband "Total transit:"]
       ['tunntype "Tunnel type:"]
       ['conntime "Connected time:"]
       ['currserv "Current server:"]
       ['rtt "Latency:"]
       ['disconnect "Disconnect"]
       ['connect "Connect"]
       ['entrynode "Set up a node"]
       ['actions "Actions"]
       ['probe "Probing internet..."]
       ['nointernet "No internet connection found! Stopping."]
       
       
       ['prism-on "Activating multiplex layer..."]
       ['multitun-on "Kirisurf connected!"]
       
       ['tunnsets "Tunnel settings:"]
       ['usebrowser "Start up browser automatically"]
       ['finding "Finding servers..."]
       ['connecting "Connecting..."]
       ['pinging "Pinging servers..."]
       ['connected "Connected!"]
       ['disconnected "Disconnected."]
       ['cantreport "Reporting bugs requires Kirisurf to connect to an anti-blocking server correctly. If this cannot be done, report bugs by sending e-mails to yd2dong@uwaterloo.ca"]
       )]
    ["cn"
     (match key
       ['version "2.0.0"]
       ['name "迷雾通"]
       ['overview "概览"]
       ['details "细节"]
       ['settings "设置"]
       ['reportbug "报告错误"]
       
       ['dlspeed "即时速度："]
       ['totband "总流量："]
       ['tunntype "通道类型："]
       ['conntime "连接时间："]
       ['currserv "节点："]
       ['rtt "延迟："]
       ['disconnect "断开连接"]
       ['connect "重新连接"]
       
       ['tunnsets "通道设置："]
       ['usebrowser "自动启动浏览器"]
       ['finding "正在搜索服务器..."]
       ['connecting "正在连接..."]
       ['pinging "正在挑选最快服务器..."]
       ['connected "已连接！"]
       ['disconnected "已断开。"]
       ['cantreport "报告错误需要迷雾通连接。如果不能连接，请发邮件到 yd2dong@uwaterloo.ca"]
       )]))

(provide (all-defined-out))