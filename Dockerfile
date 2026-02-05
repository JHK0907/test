# 저용량 nginx 이미지 기반
FROM nginx:stable-alpine

# 웹 서비스 용 코드 복사
COPY src/ /usr/share/nginx/html/

# 80 포트 오픈
EXPOSE 80

# nginx 포그라운드 실행
CMD ["nginx", "-g", "daemon off;"]
