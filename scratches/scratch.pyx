# -*- coding: utf-8 -*-
import json
import os
import re
import urllib.request
import feedparser
import random

from bs4 import BeautifulSoup
from slackclient import SlackClient
from flask import Flask, request, make_response, render_template

f = feedparser.parse('http://www.itfind.or.kr/rss/trend.do?rssType=02')

app = Flask(__name__)

slack_token = "xoxb-506062083639-507465023586-GzPLxXKK3rdun9sgXGOatMWX" #자신의 토큰 값을 입력해줍니다.
slack_client_id = "506062083639.507663674693" #client_id 값을 입력합니다.
slack_client_secret = "fe8b52085a70d637b21d270dfb5275af" #client_secret 값을 입력합니다.
slack_verification = "gg4J0w7jMDz0Cm4FFhCp2EmF" #verification 값을 입력합니다.

sc = SlackClient(slack_token)

# 크롤링 함수 구현하기
def _crawl_keywords(text):
  #url = re.search(r'(https?://\S+)', text.split('|')[0]).group(0)
  url = 'http://www.itfind.or.kr/rss/trend.do?rssType=02'
  req = urllib.request.Request(url)
  sourcecode = urllib.request.urlopen(url).read()
  soup = BeautifulSoup(sourcecode, "html.parser")
  title=[]
  title_1={}
  keywords = []
  description_1={}
  line_num=1
  # Print all title in entries
  for feed in f['entries']:
      keywords = feed.description
      keywords += "\n\n"
      title=feed.title
      line_num+=1
      description_1[line_num]=keywords
      title_1[line_num]=title
  ran_num=random.randrange(1,line_num+1)
  keywords="<" + title_1[ran_num] + ">\n"
  keywords+= description_1[ran_num]
  print(keywords)

  #for i, keyword in enumerate(soup.find_all("item", class_="title")):
  #    if i < 10:
  #        keywords.append(keyword.get_text())
  return u''.join(keywords)
  # 한글 지원을 위해 앞에 unicode u를 붙힙니다.


# 이벤트 핸들하는 함수
def _event_handler(event_type, slack_event):
  print(slack_event["event"])

  if event_type == "app_mention":
      channel = slack_event["event"]["channel"]
      text = slack_event["event"]["text"]

      keywords = _crawl_keywords(text)
      sc.api_call(
          "chat.postMessage",
          channel=channel,
          text=keywords
      )

      return make_response("App mention message has been sent", 200,)

  # ============= Event Type Not Found! ============= #
  # If the event_type does not have a handler
  message = "You have not added an event handler for the %s" % event_type
  # Return a helpful error message
  return make_response(message, 200, {"X-Slack-No-Retry": 1})

@app.route("/listening", methods=["GET", "POST"])
def hears():
  slack_event = json.loads(request.data)

  if "challenge" in slack_event:
      return make_response(slack_event["challenge"], 200, {"content_type":
                                                           "application/json"
                                                          })

  if slack_verification != slack_event.get("token"):
      message = "Invalid Slack verification token: %s" % (slack_event["token"])
      make_response(message, 403, {"X-Slack-No-Retry": 1})

  if "event" in slack_event:
      event_type = slack_event["event"]["type"]
      return _event_handler(event_type, slack_event)

  # If our bot hears things that are not events we've subscribed to,
  # send a quirky but helpful error response
  return make_response("[NO EVENT IN SLACK REQUEST] These are not the droids\
                       you're looking for.", 404, {"X-Slack-No-Retry": 1})

@app.route("/", methods=["GET"])
def index():
  return "<h1>Server is ready!!!!!!!.</h1>"

if __name__ == '__main__':
  app.run('127.0.0.1', port=5000)