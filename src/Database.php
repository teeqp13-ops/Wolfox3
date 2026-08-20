<?php

declare(strict_types=1);

namespace WolFox\Store;

use PDO;
use RuntimeException;

final class Database
{
    private PDO $pdo;

    public function __construct(?string $path = null)
    {
        $configured = $path ?? Config::get('DB_PATH', './data/store.sqlite') ?? './data/store.sqlite';
        if (!str_starts_with($configured, '/')) {
            $configured = dirname(__DIR__) . '/' . ltrim($configured, './');
        }

        $directory = dirname($configured);
        if (!is_dir($directory) && !mkdir($directory, 0775, true) && !is_dir($directory)) {
            throw new RuntimeException('Unable to create SQLite directory.');
        }

        $this->pdo = new PDO('sqlite:' . $configured, null, null, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES => false,
        ]);
        $this->pdo->exec('PRAGMA foreign_keys = ON');
        $this->pdo->exec('PRAGMA journal_mode = WAL');
        $this->pdo->exec('PRAGMA busy_timeout = 5000');
    }

    public function pdo(): PDO
    {
        return $this->pdo;
    }

    public function migrate(): void
    {
        $schema = file_get_contents(dirname(__DIR__) . '/database/schema.sql');
        if ($schema === false) {
            throw new RuntimeException('Database schema is missing.');
        }
        $this->pdo->exec($schema);
    }
}
