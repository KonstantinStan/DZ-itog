# Итоговый отчёт: развёртывание и мониторинг audit-svc

> Важно: этот файл — каркас отчёта. После запуска на своём стенде приложите реальные скриншоты и логи в `screenshots/`. Не оставляйте утверждения о проверках, которые фактически не выполнялись.

## Задание 1. Сборка и публикация образа
- Dockerfile использует multistage-сборку, запускает процесс от `appuser`, есть `.dockerignore`.
- Workflow выполняет тесты с JUnit XML, загружает отчёт как artifact, собирает и публикует образ `main_<короткий SHA>` или `vX.Y.Z`.
- Доказательства: `screenshots/01-main-pipeline.png`, `screenshots/02-package-main.png`, `screenshots/03-release-pipeline.png`.

## Задание 2. База данных и секреты
- PostgreSQL `17`, именованный том `audit-postgres-data`, порт опубликован только на `127.0.0.1:5433`.
- Ansible обеспечивает роль `audit_svc` и БД `audit`, владельцем которой является `audit_svc`.
- Пароли находятся в зашифрованном `deploy/inventories/prom/group_vars/all/vault.yml`; пароль Vault передаётся из GitHub Environment secret `ANSIBLE_VAULT_PASSWORD`.
- Доказательства: вывод Ansible без секретов и проверка тома/портов в `screenshots/`.

## Задание 3. Деплой и перечитывание конфигурации
- Deploy job запускается на тегах `v*` на self-hosted runner с меткой `deploy`.
- Конфиг генерируется из шаблона с правами `0640`; при изменении он уведомляет handler, который вызывает `POST /reload`.
- Доказательства смены пароля:
  1. `docker inspect -f '{{.State.StartedAt}}' audit-svc` до изменения;
  2. смена `vault_audit_svc_password` через `ansible-vault edit`, новый коммит и релизный тег;
  3. лог задачи изменения пользователя, шаблона и handler;
  4. `StartedAt` не изменился, сервис пишет `config reloaded, reconnected to the database`, `/healthz` возвращает 200.
- Доказательство идемпотентности: повторный запуск playbook с `changed=0` и без запуска handler.

## Задание 4. Nginx и nginx-exporter
- Только Nginx (`8088`) и exporter (`9113`) публикуют порты; PostgreSQL доступен с хоста только через loopback, сервис напрямую не опубликован.
- Nginx возвращает 404 для `/reload` и обходных вариантов пути.
- Exporter использует `nginx/nginx-prometheus-exporter:1.4` и сообщает `nginx_up 1`.
- Доказательства: команды из задания и вывод `docker ps --format '{{.Names}}\t{{.Ports}}'` в `screenshots/`.

## Задание 5. Prometheus и Grafana
- Prometheus опрашивает метрики сервиса через Nginx и метрики Nginx через exporter.
- Дашборды `monitoring/grafana/audit-svc.json` и `monitoring/grafana/nginx.json` загружаются Grafana provisioning.
- Запустить `generate` не менее чем на 600 секунд.
- Доказательства: `/targets` с обеими целями UP, оба дашборда с данными, панель `Сервис запущен` в состояниях UP и DOWN.

## Дополнительное задание: миграции
- `migrate` выполняется до обновления контейнера сервиса; ошибка миграции прерывает playbook.
- Для демонстрации добавьте `0003_*.sql`, выпустите новый тег и приложите лог `applying 0003_...`.
