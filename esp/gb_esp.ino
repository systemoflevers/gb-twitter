#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <SPI.h>

#include "wifi_credentials.h"

const byte kInputInterruptPin = 5;  // Wemos D1
const byte kIOClockPin = 14;        // Wemos D5
const byte kInputDataPin = 12;      // Wemos D6
const byte kOutputDataPin = 13;     // Wemos D7
const byte kPLStrobePin = 16;       // Wemos D0. PL is active low.
const byte kOutputInterruptPin = 0; // Wemos D3
volatile bool inputWaiting = false;
volatile bool outputWaiting = false;

// changes state to indicate ready
const byte kReadyPin = 4; // Wemos D2

auto serial = Serial1;
WiFiClient client;

bool first_connection = true;
void connectWifi()
{
  if (WiFi.status() == WL_CONNECTED)
    return;

  WiFi.forceSleepWake();
  delay(1);

  if (first_connection)
  {
    WiFi.begin(WIFI_SSID, WIFI_PWD);
    first_connection = false;
  }
  else
  {
    WiFi.begin();
  }

  serial.println(F("Connecting"));
  while (WiFi.status() != WL_CONNECTED && WiFi.waitForConnectResult() != WL_CONNECTED)
  {
    delay(50);
    serial.print(".");
  }
  serial.println();

  serial.println(F("Connected, IP address: "));
  serial.println(WiFi.localIP());
}

SPISettings inputSpiSettings(20000000, MSBFIRST, SPI_MODE3);
SPISettings outputSpiSettings(20000000, MSBFIRST, SPI_MODE0);

byte inputs[20] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
byte outputs[20] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
int inIntPin[10];
int iipc = 0;

int iC = 0;
int readInputCounter = 0;

void handleInputInterrupt()
{
  serial.print("i");
  byte value = readInput();
  //byte value = spiReadInput();
  serial.println(String(": ") + value);
  inputWaiting = true;
  return;
}

void handleOutputInterrupt()
{
  outputWaiting = false;
  digitalWrite(kReadyPin, HIGH);
  serial.print("o");
}

byte readInput()
{
  digitalWrite(kPLStrobePin, HIGH);
  byte v = shiftIn(kInputDataPin, kIOClockPin, MSBFIRST);
  digitalWrite(kPLStrobePin, LOW);
  digitalWrite(kIOClockPin, HIGH);
  inputWaiting = false;
  return v;
}

void writeToGB(byte data)
{
  digitalWrite(kIOClockPin, LOW);
  shiftOut(kOutputDataPin, kIOClockPin, MSBFIRST, data);
  digitalWrite(kPLStrobePin, HIGH);
  digitalWrite(kPLStrobePin, LOW);
  digitalWrite(kIOClockPin, HIGH);
  outputWaiting = true;
}

byte spiReadInput()
{
  SPI.beginTransaction(inputSpiSettings);
  digitalWrite(kPLStrobePin, HIGH);
  byte inData = SPI.transfer(0x00);
  digitalWrite(kPLStrobePin, LOW);
  SPI.endTransaction();

  return inData;
}

void spiWriteToGB(byte outData)
{
  SPI.beginTransaction(outputSpiSettings);
  SPI.transfer(outData);
  digitalWrite(kPLStrobePin, HIGH);
  digitalWrite(kPLStrobePin, LOW);

  SPI.endTransaction();
  outputWaiting = true;
}

unsigned long t;
void setup()
{
  serial.begin(9600);
  serial.println("");
  serial.println("hi!");

  // turn off wifi modem
  WiFi.disconnect();
  //WiFi.forceSleepBegin();
  delay(100);

  // setup input control
  pinMode(kInputInterruptPin, INPUT);
  attachInterrupt(digitalPinToInterrupt(kInputInterruptPin), handleInputInterrupt, CHANGE);
  attachInterrupt(digitalPinToInterrupt(kOutputInterruptPin), handleOutputInterrupt, CHANGE);

  pinMode(kIOClockPin, OUTPUT);
  digitalWrite(kIOClockPin, HIGH);
  pinMode(kInputDataPin, INPUT);
  pinMode(kOutputDataPin, OUTPUT);

  pinMode(kPLStrobePin, OUTPUT);
  digitalWrite(kPLStrobePin, LOW);

  pinMode(kReadyPin, OUTPUT);
  digitalWrite(kReadyPin, HIGH);

  connectWifi();

  writeToGB(255);
  digitalWrite(kReadyPin, LOW);

  t = 0; //millis();
}

String getTweet(String id)
{
  String url = TWITTER_APP_URL;
  url += "read=";
  url += id;
  serial.println("[HTTP] URL: " + url);
  HTTPClient http;
  http.begin(url);
  int httpCode = http.GET();

  if (httpCode > 0)
  {
    // HTTP header has been send and Server response header has been handled
    serial.printf("[HTTP] GET... code: %d\n", httpCode);

    // file found at server
    if (httpCode == HTTP_CODE_OK)
    {
      String payload = http.getString();
      serial.println("payload:");
      serial.println(payload);
      return payload;
      serial.println("******");
      payload.trim();
      serial.println("trimmed:");
      serial.println(payload);
      
      return payload;
    }
  }
  else
  {
    serial.printf("[HTTP] GET... failed, error: %s\n", http.errorToString(httpCode).c_str());
    return "";
  }
}

String likeTweet(String id)
{
  String url = TWITTER_APP_URL;
  url += "like=";
  url = url + id;
  serial.println("[HTTP] URL: " + url);
  HTTPClient http;
  http.begin(url);
  int httpCode = http.GET();

  if (httpCode > 0)
  {
    // HTTP header has been send and Server response header has been handled
    serial.printf("[HTTP] GET... code: %d\n", httpCode);

    // file found at server
    if (httpCode == HTTP_CODE_OK)
    {
      String payload = http.getString();
      serial.println("payload:");
      serial.println(payload);
      return payload;
      serial.println("******");
      payload.trim();
      serial.println("trimmed:");
      serial.println(payload);
      
      return payload;
    }
  }
  else
  {
    serial.printf("[HTTP] GET... failed, error: %s\n", http.errorToString(httpCode).c_str());
    return "";
  }
}

enum State {
  kConnecting,
  kConnected,
  kGettingTweet,
  kSendingToGB,
  kWaitingForLike,
  kDone,
};

String tweet = "";
int tweetPlace = 0;
State state = kConnected;

// mine 1471717599096590340
String tweetId = "1471428560846000128";
void loop()
{
  if (outputWaiting)
    return;
  if (state == kDone)
    return;

  if (state == kConnected)
  {
    serial.println("trying to get tweet");
    tweet = getTweet(tweetId);
    //digitalWrite(kReadyPin, LOW);
    state = kSendingToGB;
    return;
  }
  if (state == kSendingToGB) {
    //serial.println("sending to gb");
    if (tweetPlace >= tweet.length()) {
      serial.println("done sending 0");
      writeToGB(0);
      digitalWrite(kReadyPin, LOW);
      serial.println("0 sent");
      state = kWaitingForLike;
      return;
    }
    if (outputWaiting) return;
    char c = tweet.charAt(tweetPlace);
    ++tweetPlace;
    writeToGB(c);
    digitalWrite(kReadyPin, LOW);
    return;
  }
  if (state == kWaitingForLike && inputWaiting) {
    char c = readInput();
    likeTweet(tweetId);
    serial.println("did like telling gb");
    writeToGB(1);
    digitalWrite(kReadyPin, LOW);
    state = kDone;
    serial.println("done done");
    return;
  }
}
