This is a proof-of-concept twitter client for the GameBoy. It uses a custom Wi-Fi enabled GameBoy cartridge described on my [blog](https://www.systemoflevers.com/blog/2021/12/16/gameboy-wifi-cart/index.html). It can load and display a single tweet on the GameBoy and has minimal UI that lets you *like* that tweet.

This repository includes the code for the GameBoy ROM, the ESP, the ATF16V8 PLD (used to coordinate between the GameBoy and the ESP), and a web-service that talks to Twitter.

The user's auth credentials are hardcoded in the web service and the tweet ID is hardcoded in the ESP code. There's no UI for viewing other tweets.
