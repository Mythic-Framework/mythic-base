-- Schema definitions for the MythicFrame Database component if theres a better way pr this plz
-- Every table used by any script must be defined here since base creates it
-- cols:     scalar SQL columns  { fieldName = 'SQL_TYPE' }
-- jsonCols: array/object fields stored as JSON text
-- indexes:  additional indexed columns (beyond _id primary key)
-- No overflow — unknown fields log a warning and are ignored

DB_SCHEMAS = {

    -- Core

    characters = {
        cols = {
            SID        = 'INT',
            User       = 'VARCHAR(64)',
            First      = 'VARCHAR(64)',
            Last       = 'VARCHAR(64)',
            Phone      = 'VARCHAR(20)',
            DOB        = 'VARCHAR(20)',
            Gender     = 'TINYINT DEFAULT 0',
            Cash       = 'BIGINT DEFAULT 0',
            HP         = 'INT DEFAULT 200',
            Armor      = 'INT DEFAULT 0',
            LastPlayed = 'BIGINT DEFAULT -1',
            New        = 'TINYINT(1) DEFAULT 1',
            Deleted    = 'TINYINT(1) DEFAULT 0',
            Bio          = 'TEXT',
            Origin       = 'VARCHAR(128)',
            Apartment    = 'INT',
            CryptoWallet = 'VARCHAR(64)',
            BankAccount  = 'INT',
            default      = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = { 'Jobs', 'Licenses', 'States', 'Jailed', 'ICU', 'GangChain', 'Parole', 'MDTHistory', 'Alias', 'Apps', 'PhoneSettings', 'PhonePermissions', 'LaptopApps', 'LaptopSettings', 'LaptopPermissions', 'Crypto', 'Wardrobe', 'Status', 'Animations', 'Addiction' },
        indexes  = { 'SID', 'User', 'Deleted', 'CryptoWallet' },
    },

    jobs = {
        cols = {
            Id          = 'VARCHAR(64)',
            Name        = 'VARCHAR(128)',
            Type        = 'VARCHAR(64)',
            Custom      = 'TINYINT(1) DEFAULT 0',
            Hidden      = 'TINYINT(1) DEFAULT 0',
            Owner       = 'INT',
            Salary      = 'INT DEFAULT 0',
            SalaryTier  = 'INT DEFAULT 1',
            LastUpdated = 'BIGINT DEFAULT 0',
            default     = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = { 'Grades', 'Workplaces', 'Permissions' },
        indexes  = { 'Id' },
    },

    locations = {
        cols = {
            Type    = 'VARCHAR(64)',
            Name    = 'VARCHAR(128)',
            default = 'TINYINT(1) DEFAULT 0',
            x       = 'FLOAT DEFAULT 0',
            y       = 'FLOAT DEFAULT 0',
            z       = 'FLOAT DEFAULT 0',
            Heading = 'FLOAT DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'Type' },
    },

    logs = {
        cols = {
            date      = 'BIGINT',
            level     = 'INT',
            component = 'VARCHAR(64)',
            log       = 'TEXT',
        },
        jsonCols = { 'data' },
        indexes  = { 'level', 'date' },
    },

    defaults = {
        cols = {
            collection = 'VARCHAR(64)',
            date       = 'BIGINT DEFAULT 0',
            default    = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = { 'data' },
        indexes  = { 'collection' },
    },

    changelogs = {
        cols = {
            date    = 'BIGINT DEFAULT 0',
            version = 'VARCHAR(32)',
        },
        jsonCols = {},
        indexes  = { 'date' },
    },

    -- Auth

    users = {
        cols = {
            identifier = 'VARCHAR(128)',
            name       = 'VARCHAR(128)',
            account    = 'INT',
            verified   = 'TINYINT(1) DEFAULT 1',
            joined     = 'BIGINT DEFAULT 0',
            avatar     = 'VARCHAR(256)',
            priority   = 'INT DEFAULT 0',
            forum      = 'VARCHAR(128)',
        },
        jsonCols = { 'tokens', 'groups' },
        indexes  = { 'identifier', 'account' },
    },

    bans = {
        cols = {
            account    = 'VARCHAR(64)',
            identifier = 'VARCHAR(128)',
            expires    = 'BIGINT',
            reason     = 'TEXT',
            issuer     = 'VARCHAR(64)',
            active     = 'TINYINT(1) DEFAULT 1',
            started    = 'BIGINT',
        },
        jsonCols = { 'tokens' },
        indexes  = { 'account', 'identifier', 'active' },
    },

    roles = {
        cols = {
            Abv           = 'VARCHAR(64)',
            Name          = 'VARCHAR(128)',
            default       = 'TINYINT(1) DEFAULT 0',
            QueuePriority = 'INT DEFAULT 0',
            QueueMessage  = 'VARCHAR(128)',
            PermLevel     = 'INT DEFAULT 0',
            PermGroup     = 'VARCHAR(64) DEFAULT ""',
        },
        jsonCols = {},
        indexes  = { 'Abv', 'PermLevel' },
    },

    -- Vehicles

    vehicles = {
        cols = {
            VIN             = 'VARCHAR(64)',
            RegisteredPlate = 'VARCHAR(16)',
            FakePlate       = 'VARCHAR(16)',
            Type            = 'INT DEFAULT 0',
            OwnerType       = 'INT DEFAULT 0',
            Job             = 'VARCHAR(64)',
            radarFlag       = 'TINYINT(1) DEFAULT 0',
            Impound         = 'TINYINT(1) DEFAULT 0',
            Out             = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = { 'Owner', 'Flags', 'Mods', 'Insurance' },
        indexes  = { 'VIN', 'RegisteredPlate', 'OwnerType' },
    },

    -- Firearms

    firearms = {
        cols = {
            serial = 'VARCHAR(64)',
            owner  = 'INT',
            model  = 'VARCHAR(64)',
        },
        jsonCols = {},
        indexes  = { 'serial', 'owner' },
    },

    firearms_projectiles = {
        cols = {
            serial = 'VARCHAR(64)',
            weapon = 'VARCHAR(64)',
            date   = 'BIGINT DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'serial', 'weapon' },
    },

    -- Banking

    bank_accounts = {
        cols = {
            Account = 'VARCHAR(64)',
            Name    = 'VARCHAR(128)',
            Balance = 'BIGINT DEFAULT 0',
            Type    = 'VARCHAR(32)',
            Owner   = 'VARCHAR(64)',
            Frozen  = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = { 'JointOwners', 'JobAccess' },
        indexes  = { 'Account', 'Type', 'Owner' },
    },

    bank_accounts_transactions = {
        cols = {
            Account            = 'VARCHAR(64)',
            Amount             = 'BIGINT DEFAULT 0',
            Type               = 'VARCHAR(32)',
            Title              = 'VARCHAR(256)',
            Description        = 'TEXT',
            Timestamp          = 'BIGINT DEFAULT 0',
            TransactionAccount = 'VARCHAR(64)',
        },
        jsonCols = { 'Data' },
        indexes  = { 'Account', 'Timestamp' },
    },

    -- Loans

    loans = {
        cols = {
            SID              = 'INT',
            Amount           = 'BIGINT DEFAULT 0',
            Remaining        = 'BIGINT DEFAULT 0',
            MissedPayments   = 'INT DEFAULT 0',
            MissablePayments = 'INT DEFAULT 0',
            Active           = 'TINYINT(1) DEFAULT 1',
            date             = 'BIGINT DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'SID', 'Active' },
    },

    loans_credit_scores = {
        cols = {
            SID   = 'INT',
            Score = 'INT DEFAULT 700',
        },
        jsonCols = {},
        indexes  = { 'SID' },
    },

    -- Dealerships

    dealer_data = {
        cols = {
            dealership = 'VARCHAR(64)',
        },
        jsonCols = { 'settings' },
        indexes  = { 'dealership' },
    },

    dealer_showrooms = {
        cols = {
            dealership = 'VARCHAR(64)',
        },
        jsonCols = { 'showroom' },
        indexes  = { 'dealership' },
    },

    dealer_stock = {
        cols = {
            dealership   = 'VARCHAR(64)',
            vehicle      = 'VARCHAR(64)',
            make         = 'VARCHAR(64)',
            model        = 'VARCHAR(64)',
            category     = 'VARCHAR(64)',
            class        = 'VARCHAR(8)',
            price        = 'INT DEFAULT 0',
            quantity     = 'INT DEFAULT 0',
            lastStocked  = 'BIGINT DEFAULT 0',
            lastPurchase = 'BIGINT DEFAULT 0',
            default      = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = { 'data' },
        indexes  = { 'dealership', 'vehicle' },
    },

    dealer_records = {
        cols = {
            dealership    = 'VARCHAR(64)',
            SID           = 'INT',
            time          = 'BIGINT DEFAULT 0',
            type          = 'VARCHAR(32)',
            salePrice     = 'BIGINT DEFAULT 0',
            dealerProfits = 'BIGINT DEFAULT 0',
            profitPercent = 'FLOAT DEFAULT 0',
            Hidden        = 'TINYINT(1) DEFAULT 0',
            _search       = 'TEXT',
        },
        jsonCols = { 'vehicle', 'buyer', 'loan', 'previousOwner' },
        indexes  = { 'dealership', 'SID', 'time' },
    },

    dealer_records_buybacks = {
        cols = {
            dealership    = 'VARCHAR(64)',
            SID           = 'INT',
            time          = 'BIGINT DEFAULT 0',
            type          = 'VARCHAR(32)',
            Hidden        = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = { 'vehicle', 'previousOwner' },
        indexes  = { 'dealership', 'SID', 'time' },
    },

    -- Doors

    doors_custom = {
        cols = {
            Name = 'VARCHAR(128)',
        },
        jsonCols = { 'Coords', 'Locks' },
        indexes  = {},
    },

    elevators_custom = {
        cols = {
            Name = 'VARCHAR(128)',
        },
        jsonCols = { 'Floors' },
        indexes  = {},
    },

    -- Properties

    properties = {
        cols = {
            owner       = 'INT',
            type        = 'VARCHAR(64)',
            Name        = 'VARCHAR(128)',
            Active      = 'TINYINT(1) DEFAULT 1',
            interior    = 'INT DEFAULT 0',
            price       = 'BIGINT DEFAULT 0',
            label       = 'VARCHAR(256)',
            sold        = 'TINYINT(1) DEFAULT 0',
            foreclosed  = 'TINYINT(1) DEFAULT 0',
            foreclosedTime = 'BIGINT DEFAULT 0',
            locked      = 'TINYINT(1) DEFAULT 1',
            default     = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = { 'Coords', 'Doors', 'Shells', 'location', 'keys', 'upgrades' },
        indexes  = { 'owner', 'type', 'Active', 'sold', 'foreclosed' },
    },

    properties_furniture = {
        cols = {
            Property = 'INT',
        },
        jsonCols = { 'Furniture' },
        indexes  = { 'Property' },
    },

    -- Scenes

    scenes = {
        cols = {
            Creator = 'INT',
            date    = 'BIGINT DEFAULT 0',
            expires = 'BIGINT DEFAULT 0',
            staff   = 'TINYINT(1) DEFAULT 0',
            route   = 'INT DEFAULT 0',
        },
        jsonCols = { 'Objects' },
        indexes  = { 'Creator', 'expires', 'staff' },
    },

    -- Peds

    peds = {
        cols = {
            Char = 'INT',
        },
        jsonCols = { 'Ped', 'Skin', 'Tattoos', 'Clothes' },
        indexes  = { 'Char' },
    },

    -- Casino

    casino_bigwins = {
        cols = {
            SID    = 'INT',
            Amount = 'BIGINT DEFAULT 0',
            Game   = 'VARCHAR(64)',
            date   = 'BIGINT DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'SID', 'date' },
    },

    casino_config = {
        cols = {
            key = 'VARCHAR(128)',
        },
        jsonCols = { 'data' },
        indexes  = { 'key' },
    },

    -- Businesses

    business_tvs = {
        cols = {
            Business = 'VARCHAR(64)',
        },
        jsonCols = { 'config' },
        indexes  = { 'Business' },
    },

    storage_units = {
        cols = {
            Business = 'VARCHAR(64)',
            Owner    = 'INT',
        },
        jsonCols = {},
        indexes  = { 'Business', 'Owner' },
    },

    billboards = {
        cols = {
            Id = 'VARCHAR(64)',
        },
        jsonCols = { 'data' },
        indexes  = { 'Id' },
    },

    business_notices = {
        cols = {
            Business = 'VARCHAR(64)',
            Author   = 'INT',
            date     = 'BIGINT DEFAULT 0',
            content  = 'TEXT',
        },
        jsonCols = {},
        indexes  = { 'Business' },
    },

    business_receipts = {
        cols = {
            Business = 'VARCHAR(64)',
            SID      = 'INT',
            date     = 'BIGINT DEFAULT 0',
            Amount   = 'BIGINT DEFAULT 0',
        },
        jsonCols = { 'items' },
        indexes  = { 'Business', 'SID', 'date' },
    },

    business_documents = {
        cols = {
            Business = 'VARCHAR(64)',
            Author   = 'INT',
            Title    = 'VARCHAR(256)',
            date     = 'BIGINT DEFAULT 0',
            content  = 'TEXT',
        },
        jsonCols = {},
        indexes  = { 'Business' },
    },

    -- Phone

    phone_messages = {
        cols = {
            owner   = 'VARCHAR(20)',
            number  = 'VARCHAR(20)',
            message = 'TEXT',
            time    = 'BIGINT DEFAULT 0',
            method  = 'INT DEFAULT 0',
            unread  = 'TINYINT(1) DEFAULT 1',
            deleted = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'owner', 'number', 'time', 'deleted' },
    },

    phone_calls = {
        cols = {
            owner       = 'VARCHAR(20)',
            number      = 'VARCHAR(20)',
            duration    = 'INT DEFAULT 0',
            time        = 'BIGINT DEFAULT 0',
            method      = 'INT DEFAULT 0',
            unread      = 'TINYINT(1) DEFAULT 1',
            deleted     = 'TINYINT(1) DEFAULT 0',
            decryptable = 'TINYINT(1) DEFAULT 0',
            anonymouse  = 'TINYINT(1) DEFAULT 0',
            incoming    = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'owner', 'number', 'time', 'deleted' },
    },

    phone_contacts = {
        cols = {
            character = 'INT',
            name      = 'VARCHAR(128)',
            number    = 'VARCHAR(20)',
            color     = 'VARCHAR(32)',
            avatar    = 'TEXT',
            favorite  = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'character', 'number' },
    },

    irc_channels = {
        cols = {
            character = 'INT',
            slug      = 'VARCHAR(64)',
            joined    = 'BIGINT DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'character', 'slug' },
    },

    irc_messages = {
        cols = {
            Channel = 'INT',
            Sender  = 'INT',
            Message = 'TEXT',
            date    = 'BIGINT DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'Channel', 'date' },
    },

    tracks_pd = {
        cols = {
            Name   = 'VARCHAR(128)',
            Owner  = 'INT',
            Active = 'TINYINT(1) DEFAULT 1',
        },
        jsonCols = { 'Songs' },
        indexes  = { 'Owner', 'Active' },
    },

    tracks = {
        cols = {
            Name   = 'VARCHAR(128)',
            Owner  = 'INT',
            Active = 'TINYINT(1) DEFAULT 1',
        },
        jsonCols = { 'Songs' },
        indexes  = { 'Owner', 'Active' },
    },

    -- Character data

    character_documents = {
        cols = {
            owner  = 'INT',
            time   = 'BIGINT DEFAULT 0',
            title  = 'VARCHAR(256)',
        },
        jsonCols = { 'content', 'sharedWith', 'signed', 'Tags', 'Authors' },
        indexes  = { 'owner', 'time' },
    },

    character_emails = {
        cols = {
            owner   = 'INT',
            sender  = 'VARCHAR(128)',
            time    = 'BIGINT DEFAULT 0',
            subject = 'VARCHAR(256)',
            body    = 'TEXT',
            unread  = 'TINYINT(1) DEFAULT 1',
            expires = 'BIGINT DEFAULT -1',
        },
        jsonCols = { 'flags' },
        indexes  = { 'owner', 'time', 'expires' },
    },

    character_convictions = {
        cols = {
            Char    = 'INT',
            Officer = 'INT',
            date    = 'BIGINT DEFAULT 0',
        },
        jsonCols = { 'charges', 'evidence', 'author' },
        indexes  = { 'Char' },
    },

    -- MDT

    mdt_charges = {
        cols = {
            title       = 'VARCHAR(256)',
            type        = 'INT DEFAULT 0',
            jail        = 'INT DEFAULT 0',
            fine        = 'INT DEFAULT 0',
            points      = 'INT DEFAULT 0',
            description = 'TEXT',
            active      = 'TINYINT(1) DEFAULT 1',
            default     = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'type', 'active' },
    },

    mdt_warrants = {
        cols = {
            state   = 'VARCHAR(32)',
            expires = 'BIGINT DEFAULT 0',
            ID      = 'INT DEFAULT 0',
        },
        jsonCols = { 'author', 'history', 'charges', 'subjects' },
        indexes  = { 'state', 'expires' },
    },

    mdt_tags = {
        cols = {
            name               = 'VARCHAR(128)',
            requiredPermission = 'VARCHAR(64)',
            restrictViewing    = 'TINYINT(1) DEFAULT 0',
            active             = 'TINYINT(1) DEFAULT 1',
            default            = 'TINYINT(1) DEFAULT 0',
        },
        jsonCols = { 'style' },
        indexes  = {},
    },

    mdt_notices = {
        cols = { default = 'TINYINT(1) DEFAULT 0' },
        jsonCols = { 'charges', 'civilians', 'officers', 'evidence' },
        indexes  = {},
    },

    mdt_reports = {
        cols = { default = 'TINYINT(1) DEFAULT 0' },
        jsonCols = { 'charges', 'civilians', 'officers', 'evidence' },
        indexes  = {},
    },

    mdt_metrics = {
        cols = {
            SID      = 'INT',
            date     = 'VARCHAR(16)',
            Reports  = 'INT DEFAULT 0',
            BOLOs    = 'INT DEFAULT 0',
            Searches = 'INT DEFAULT 0',
            Arrests  = 'INT DEFAULT 0',
            Warrants = 'INT DEFAULT 0',
        },
        jsonCols = {},
        indexes  = { 'SID', 'date' },
    },

    -- Inventory

    schematics = {
        cols = {
            SID    = 'INT',
            Item   = 'VARCHAR(64)',
            Locked = 'TINYINT(1) DEFAULT 1',
        },
        jsonCols = {},
        indexes  = { 'SID', 'Item' },
    },

    store_bank_accounts = {
        cols = {
            Store   = 'VARCHAR(64)',
            Account = 'VARCHAR(64)',
        },
        jsonCols = {},
        indexes  = { 'Store' },
    },

    entitytypes = {
        cols = {
            Type = 'VARCHAR(64)',
        },
        jsonCols = { 'data' },
        indexes  = { 'Type' },
    },
}
