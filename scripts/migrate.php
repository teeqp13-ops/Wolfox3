<?php

declare(strict_types=1);

use WolFox\Store\Database;

require dirname(__DIR__) . '/src/bootstrap.php';

$database = new Database();
$database->migrate();
fwrite(STDOUT, "WolFox Store database migrated successfully.\n");
