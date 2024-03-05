.PHONY: migrate
migrate:
	./migrations/migrate.linux-amd64 -database "mysql://indexer:indexer-password@tcp(localhost:3306)/albatross" -path ./migrations up