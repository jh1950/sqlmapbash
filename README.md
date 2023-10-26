# SQLMapBash
[SQLMap](https://sqlmap.org/) 자동화를 위한 Bash 쉘 스크립트 코드

# Operating Systems Tested
- Kali Linux 2023.3
- Ubuntu 22.04

# Installation
```bash
pip install sqlmap
wget https://raw.githubusercontent.com/jh1950/sqlmapbash/main/sqlmapbash.sh
chmod +x sqlmapbash.sh
./sqlmapbash.sh
```

## Optional
`sqlmap` 명령어를 새로운 터미널에서 실행시키려면 아래 터미널 중 하나가 설치되어 있어야 합니다.  
여러 개가 설치되어 있다면 우선 순위는 아래 순서대로 적용됩니다.

아무 것도 설치되어 있지 않으면 eval 명령어가 사용되며, SQLMap 실행 시 아무것도 표시되지 않습니다.
- `xterm`
- `gnome-terminal`

```bash
sudo apt -y install [TERMINAL] # e.g. sudo apt -y install xterm
```
