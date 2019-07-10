# MP4 local / HLS Streaming player


# Project CustomPlayer

AVPlayer에 커스터마이징이 불가능한 부분을 개선하기 위해서 VideoToolbox를 사용하여 만든 플레이어

## Functions

#### Local 파일(.mp4<H.264/AAC>) 재생
 - MPEG-4 Parser 
 - NAL Parser (H.264) 
 
#### Remote server 파일(.m3u8, .ts<H.264/AAC>) 재생 
 - M3U8 Parser 
 - TS Parser 
 - Apdative play 기능
 - TS 파일을 교차적으로 보여주는 멀티트랙 기능 

### Tech stack

* VideoToolbox / AudioToolbox
* AVFoundation


## Versioning

version 1.0
                  
## License

MIT License

## Architecture

<img width="1000" alt="tri_3" src="https://user-images.githubusercontent.com/34180216/60952707-b57de900-a336-11e9-8954-a6d639b21745.png">


## InApp

<img width="330" alt="스크린샷 2019-05-27 오전 3 38 05" src="https://user-images.githubusercontent.com/34180216/60952909-1efdf780-a337-11e9-9dbb-12dd9930193d.png">

# 참고 
h.264 에 관한 ref : https://github.com/zerdzhong/SwfitH264Demo
https://github.com/evernoteHW/AudioRecordDemo
