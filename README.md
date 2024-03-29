<h1 align="center">CPS Data Collector <a href="https://github.com/jimouris/helm/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg"></a> </h1>

## Overview

This iOS app project enables the collection of data streams using the accelerometer, microphone and camera of your smartphone device. The interface allows selecting which actives streams will be recorded, and the play button starts the recording. The stored streams are accessible using the "Files" app of iOS.

To upload your streams to a remote Supabase database, swipe left while no recording is in progress and provide the account information and server address.

## Build & Run

This project requires the latest version of Xcode and iOS 16.0 or above in the target device. Before building, ensure that Xcode manages signing automatically (under Signing & Capabilities menu), and add a new account if needed under "Team".  
After building successfully using Xcode, the app is uploaded to the target iOS device (it may be needed to "Trust" the signing certificate in iOS, under "General"->"VPN & Device Management").

<p align="center">
    <img src="./logos/twc.png" height="20%" width="20%">
</p>
<h4 align="center">Trustworthy Computing Group</h4>
