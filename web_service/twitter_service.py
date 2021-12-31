#!/usr/bin/env python3

import cgi
import os.path
import os
import datetime
import cgitb; cgitb.enable()
import sys
import logging
import tweepy

def headers():
  print("content-type: text/plain")
  print("")

def failure():
  headers()
  print("fail")
  sys.exit(0)

def get_client():
  bearer_token = "BEARER_TOKEN"
  consumer_key = "CONSUMER_KEY"
  consumer_secret = "CONSUMER_SECRET"
  access_token = "ACCESS_TOKEN"
  access_token_secret = "ACCESS_TOKEN_SECRET"
  return tweepy.Client(
    bearer_token=bearer_token,
    consumer_key=consumer_key,
    consumer_secret=consumer_secret,
    access_token=access_token,
    access_token_secret=access_token_secret
    )

def do_like(tweet_id):
  client = get_client()
  return client.like(tweet_id)

def do_read(tweet_id):
  client = get_client()
  t = client.get_tweet(tweet_id).data.text
  
  l = t.split(" ")
  lines = []
  space = 20 # 0x14
  while l:
    w = l.pop(0)
    if not lines:
      while len(w) > 18:
        lines.append(f" {w[:18]} ")
        w = w[18:]
      lines.append(f" {w}")
      continue
    if len(lines[-1]) + len(w) + 1 > 19:
      lines[-1] += " " * (20 - len(lines[-1]))
      while len(w) > 18:
        lines.append(f" {w[:18]} ")
        w = w[18:]
      lines.append(f" {w}")
      continue
    lines[-1] += f" {w}"
  return "".join(lines)
    

form = cgi.FieldStorage()
to_send = "nothing"
if "like" in form:
  to_send = do_like(form["like"].value)
elif "read" in form:
  to_send = do_read(form["read"].value)

headers()
print(to_send)
