CREATE TABLE IF NOT EXISTS `transactions` (
    `hash` VARCHAR(100) NOT NULL,
    `from` VARCHAR(50) NOT NULL,
    `fromType` INT NOT NULL,
    `to` VARCHAR(50) NOT NULL,
    `toType` INT NOT NULL,
    `blockNumber` BIGINT UNSIGNED NOT NULL,
    `value` BIGINT UNSIGNED NOT NULL,
    `fee` BIGINT UNSIGNED NOT NULL,
    `executionResult` BOOLEAN NOT NULL DEFAULT FALSE, 
    `recipientData` TEXT NOT NULL DEFAULT '',
    `senderData` TEXT NOT NULL DEFAULT '',
    `proof` TEXT NOT NULL,
    `confirmations` INT NOT NULL,
    `validityStartHeight` BIGINT UNSIGNED NOT NULL,
    `timestamp` BIGINT UNSIGNED NOT NULL,
    `flags` INT NOT NULL,
    `networkId` INT NOT NULL,
    `enriched` JSON,

    PRIMARY KEY (`hash`)
);

CREATE INDEX `txs_idx_block_number_desc` ON `transactions` (blockNumber DESC);
CREATE INDEX `txs_idx_address_address` ON `transactions` (`from`, `to`);

CREATE TABLE IF NOT EXISTS `inherents` (
    `id` MEDIUMINT NOT NULL AUTO_INCREMENT,
    `hash` VARCHAR(100),
    `validatorAddress` VARCHAR(50) NOT NULL,
    `target` VARCHAR(50),
    `type` VARCHAR(50) NOT NULL,
    `blockNumber` BIGINT UNSIGNED NOT NULL,
    `value` BIGINT UNSIGNED,
    `blockTime` BIGINT UNSIGNED NOT NULL,
    `offensiveEventBlock` BIGINT UNSIGNED,

    PRIMARY KEY (`id`)
);

CREATE INDEX `inherents_idx_block_number_desc` ON `inherents` (blockNumber DESC);


CREATE TABLE IF NOT EXISTS `cursors` (
    `id` VARCHAR(30) NOT NULL,
    `cursor` BIGINT UNSIGNED NOT NULL,

    PRIMARY KEY (`id`)
);

CREATE TABLE IF NOT EXISTS `syncer_jobs` (
    `id` MEDIUMINT NOT NULL AUTO_INCREMENT,
    `start_number` BIGINT UNSIGNED NOT NULL,
    `end_number` BIGINT UNSIGNED NOT NULL,
    `delete_first` BOOLEAN NOT NULL DEFAULT FALSE,
    `status` VARCHAR(50) NOT NULL,

    PRIMARY KEY (`id`)
);