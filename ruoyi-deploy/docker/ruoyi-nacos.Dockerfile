FROM apache/kafka:3.9.0

USER root
WORKDIR /ruoyi/nacos

ENV TZ=Asia/Shanghai \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    JAVA_OPTS="-Xms512m -Xmx1024m"

COPY RuoYi-Cloud-Plus/ruoyi-visual/ruoyi-nacos/target/ruoyi-nacos.jar /ruoyi/nacos/app.jar

EXPOSE 8848 9848 9849

ENTRYPOINT ["sh", "-c", "java -Djava.security.egd=file:/dev/./urandom ${JAVA_OPTS} -jar /ruoyi/nacos/app.jar"]
