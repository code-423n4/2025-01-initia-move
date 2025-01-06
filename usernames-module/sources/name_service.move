module usernames::usernames {
    use std::error;
    use std::event::Self;
    use std::string::{Self, String};
    use std::signer;
    use std::vector;

    use initia_std::block;    
    use initia_std::coin;
    use initia_std::bigdecimal;
    use initia_std::dex::{Self, Config as PairConfig};
    use initia_std::object::{Self, ExtendRef, Object};
    use initia_std::option::{Self, Option};
    use initia_std::table::{Self, Table};
    use initia_std::nft::Nft;
    use initia_std::initia_nft;
    use initia_std::primary_fungible_store;
    use initia_std::fungible_asset::{Metadata as CoinMetadata};

    use usernames::metadata::{Self, Metadata};

    /// Only chain can execute.
    const EUNAUTHORIZED: u64 = 0;

    /// module store already exist.
    const EMODULE_STORE_ALREADY_PUBLISHED: u64 = 1;

    /// duration must be bigger than min_duration
    const EMIN_DURATION: u64 = 3;

    /// name already taken
    const EDOMAIN_NAME_ALREADY_EXISTS: u64 = 4;

    /// name length must be more bigger than or equal to 3
    const EMIN_NAME_LENGTH: u64 = 5;

    /// name length must be more bigger than or equal to 3
    const EMAX_NAME_LENGTH: u64 = 6;

    /// invalid charactor
    const EINVALID_CHARACTOR: u64 = 7;

    /// not an owner of the token
    const ENOT_OWNER: u64 = 8;

    /// token is expired
    const ETOKEN_EXPIRED: u64 = 9;

    /// token id not found
    const ETOKEN_ID_NOT_FOUND: u64 = 10;

    /// name not found
    const ENAME_NOT_FOUND: u64 = 11;

    ///  address not found
    const EADDRESS_NOT_FOUND: u64 = 12;

    const EEVENT_STORE_ALREADY_PUBLISHED: u64 = 13;
    const EEVENT_STORE_NOT_PUBLISHED: u64 = 14;

    /// constants
    const YEAR_TO_SECOND: u64 = 31557600; // 365.25 * 24 * 60 * 60

    const MAX_EXPIRATION: u64 = 3155760000; // 100 years

    const TLD: vector<u8> = b".init";

    const MAX_LENGTH: u64 = 64;
    const FREE_LENGTH: u64 = 7;

    struct ModuleStore has key {
        name_to_token: Table<String, address>,

        name_to_addr: Table<String, address>,

        addr_to_name: Table<address, String>,

        creator_extend_ref: ExtendRef,

        pool: address,

        config: Config,
    }

    #[event]
    struct RegisterEvent has drop, store {
        addr: address,
        domain_name: String,
        token: address,
        expiration_date: u64,
    }

    #[event]
    struct UnsetEvent has drop, store {
        addr: address,
        domain_name: String,
    }

    #[event]
    struct SetEvent has drop, store {
        addr: address,
        domain_name: String,
    }

    #[event]
    struct ExtendEvent has drop, store {
        addr: address,
        domain_name: String,
        expiration_date: u64,
    }

    #[event]
    struct UpdateRecordsEvent has drop, store {
        addr: address,
        domain_name: String,
        keys: vector<String>,
        values: vector<String>,
    }

    #[event]
    struct DeleteRecordsEvent has drop, store {
        addr: address,
        domain_name: String,
        keys: vector<String>,
    }

    struct Config has store {
        price_per_year_3char: u64,
        price_per_year_4char: u64,
        price_per_year_default: u64,
        min_duration: u64,
        grace_period: u64,
        base_uri: String,
    }

    struct ConfigResponse has drop {
        price_per_year_3char: u64,
        price_per_year_4char: u64,
        price_per_year_default: u64,
        min_duration: u64,
        grace_period: u64,
        base_uri: String,
    }

    #[view]
    public fun get_valid_token(domain_name: String): Option<address> acquires ModuleStore {
        let module_store = borrow_global<ModuleStore>(@usernames);
        let id = if (table::contains(&module_store.name_to_token, domain_name)) {
            option::some(*table::borrow(&module_store.name_to_token, domain_name))
        } else {
            option::none()
        };

        id
    }

    #[view]
    public fun get_name_from_address(addr: address): Option<String> acquires ModuleStore {
        let module_store = borrow_global<ModuleStore>(@usernames);
        let name = if (table::contains(&module_store.addr_to_name, addr)) {
            let name = *table::borrow(&module_store.addr_to_name, addr);
            if (is_expired(name)) {
                option::none()
            } else {
                option::some(name)
            }
        } else {
            option::none()
        };

        name
    }

    #[view]
    public fun get_address_from_name(name: String): Option<address> acquires ModuleStore {
        let module_store = borrow_global<ModuleStore>(@usernames);
        let addr = if (table::contains(&module_store.name_to_addr, name)) {
            if (is_expired(name)) {
                option::none()
            } else {
                let module_store = borrow_global<ModuleStore>(@usernames);
                option::some(*table::borrow(&module_store.name_to_addr, name))
            }
        } else {
            option::none()
        };

        addr
    }

    #[view]
    public fun get_config(): ConfigResponse acquires ModuleStore {
        let module_store = borrow_global<ModuleStore>(@usernames);

        ConfigResponse {
            price_per_year_3char: module_store.config.price_per_year_3char,
            price_per_year_4char: module_store.config.price_per_year_4char,
            price_per_year_default: module_store.config.price_per_year_default,
            min_duration: module_store.config.min_duration,
            grace_period: module_store.config.grace_period,
            base_uri: module_store.config.base_uri,
        }
    }

    #[view]
    public fun get_init_cost(domain_name: String, duration: u64): u64 acquires ModuleStore {
        get_cost_amount(domain_name, duration)
    }

    /// return (price_per_year_3char, price_per_year_4char, price_per_year_default, min_duration, grace_period, base_uri)
    public fun get_config_params(): (u64, u64, u64, u64, u64, String) acquires ModuleStore {
        let module_store = borrow_global<ModuleStore>(@usernames);

        (
            module_store.config.price_per_year_3char,
            module_store.config.price_per_year_4char,
            module_store.config.price_per_year_default,
            module_store.config.min_duration,
            module_store.config.grace_period,
            module_store.config.base_uri,
        )
    }

    /// Initialize, Make global store
    public entry fun initialize(
        account: &signer,
        price_per_year_3char: u64,
        price_per_year_4char: u64,
        price_per_year_default: u64,
        min_duration: u64,
        grace_period: u64,
        base_uri: String,
        collection_uri: String,
    ) {
        assert!(signer::address_of(account) == @usernames, error::invalid_argument(EUNAUTHORIZED));
        assert!(!exists<ModuleStore>(@usernames), error::already_exists(EMODULE_STORE_ALREADY_PUBLISHED));
        let constructor_ref = object::create_named_object(account, b"usernames");
        let creator = object::generate_signer(&constructor_ref);
        let creator_extend_ref = object::generate_extend_ref(&constructor_ref);

        initia_nft::create_collection_object(
            &creator,
            string::utf8(b"Initia Usernames"),
            option::none(),
            string::utf8(b"Initia Usernames"),
            collection_uri,
            false,
            false,
            false,
            true,
            true,
            bigdecimal::zero(),
        );

        let constructor_ref = object::create_object(@initia_std, false);
        let pool = object::address_from_constructor_ref(&constructor_ref);

        move_to(
            account,
            ModuleStore {
                name_to_token: table::new(),
                name_to_addr: table::new(),
                addr_to_name: table::new(),
                creator_extend_ref,
                pool,
                config: Config {
                    price_per_year_3char,
                    price_per_year_4char,
                    price_per_year_default,
                    min_duration,
                    grace_period,
                    base_uri,
                },
            },
        );
    }

    public entry fun update_config(
        chain: &signer,
        price_per_year_3char: Option<u64>,
        price_per_year_4char: Option<u64>,
        price_per_year_default: Option<u64>,
        min_duration: Option<u64>,
        grace_period: Option<u64>,
        base_uri: Option<String>,
    ) acquires ModuleStore {
        assert!(signer::address_of(chain) == @usernames, error::invalid_argument(EUNAUTHORIZED));

        let module_store = borrow_global_mut<ModuleStore>(@usernames);

        if (option::is_some(&price_per_year_3char)) {
            module_store.config.price_per_year_3char = option::extract(&mut price_per_year_3char);
        };

        if (option::is_some(&price_per_year_4char)) {
            module_store.config.price_per_year_4char = option::extract(&mut price_per_year_4char);
        };

        if (option::is_some(&price_per_year_default)) {
            module_store.config.price_per_year_default = option::extract(&mut price_per_year_default);
        };

        if (option::is_some(&min_duration)) {
            module_store.config.min_duration = option::extract(&mut min_duration);
        };

        if (option::is_some(&grace_period)) {
            module_store.config.grace_period = option::extract(&mut grace_period);
        };

        if (option::is_some(&base_uri)) {
            module_store.config.base_uri = option::extract(&mut base_uri);
        };
    }

    public entry fun register_domain(
        account: &signer,
        domain_name: String,
        duration: u64,
    ) acquires ModuleStore {
        let addr = signer::address_of(account);

        // check expiration
        let module_store = borrow_global_mut<ModuleStore>(@usernames);
        let (_height, timestamp) = block::get_block_info();

        domain_name = to_lower_case(&domain_name);

        assert!(
            duration >= module_store.config.min_duration,
            error::invalid_argument(EMIN_DURATION),
        );

        assert!(
            duration <= MAX_EXPIRATION,
            error::invalid_argument(EMIN_DURATION),
        );

        let creator = &object::generate_signer_for_extending(&module_store.creator_extend_ref);

        if (table::contains(&module_store.name_to_token, domain_name)) {
            let token = *table::borrow(&module_store.name_to_token, domain_name);
            let expiration_date = metadata::get_expiration_date(token);

            assert!(
                expiration_date + module_store.config.grace_period < timestamp,
                error::already_exists(EDOMAIN_NAME_ALREADY_EXISTS),
            );

            table::remove(&mut module_store.name_to_token, domain_name);
            let token_uri = module_store.config.base_uri;
            string::append(&mut token_uri, string::utf8(b"expired"));
            initia_nft::set_uri(creator, object::address_to_object<Nft>(token), token_uri);
        };

        let name = domain_name;
        check_name(name);
        string::append_utf8(&mut name, TLD);
        string::append_utf8(&mut name, b":");
        string::append(&mut name, u64_to_string(timestamp));

        let token_uri = module_store.config.base_uri;
        string::append(&mut token_uri, domain_name);
        let (_, extend_ref) = initia_nft::mint_nft_object(
            creator,
            string::utf8(b"Initia Usernames"),
            string::utf8(b"Initia Usernames"),
            name,
            token_uri,
            false,
        );
        let token = object::generate_signer_for_extending(&extend_ref);
        let token_addr = object::address_from_extend_ref(&extend_ref);
        object::transfer_raw(creator, token_addr, addr);

        table::add(&mut module_store.name_to_token, domain_name, token_addr);
        metadata::create(
            &token,
            timestamp + duration,
            name,
            vector[],
            vector[],
        );

        let cost_amount = get_cost_amount(domain_name, duration);
        let module_store = borrow_global_mut<ModuleStore>(@usernames);
        let cost = primary_fungible_store::withdraw(account, get_init_metadata(), (cost_amount as u64));
        primary_fungible_store::deposit(module_store.pool, cost);

        event::emit(
            RegisterEvent {
                addr,
                domain_name,
                token: token_addr,
                expiration_date: timestamp + duration,
            },
        );
    }

    public entry fun unset_name(
        account: &signer,
    ) acquires ModuleStore {
        let addr = signer::address_of(account);
        let module_store = borrow_global_mut<ModuleStore>(@usernames);

        if (table::contains(&module_store.addr_to_name, addr)) {
            let removed_name = table::remove(&mut module_store.addr_to_name, addr);
            table::remove(&mut module_store.name_to_addr, removed_name);

            event::emit(
                UnsetEvent {
                    addr,
                    domain_name: removed_name,
                },
            );
        };
    }

    public entry fun set_name(
        account: &signer,
        domain_name: String,
    ) acquires  ModuleStore {
        let addr = signer::address_of(account);
        let (_height, timestamp) = block::get_block_info();
        domain_name = to_lower_case(&domain_name);

        let module_store = borrow_global_mut<ModuleStore>(@usernames);
        let token_addr = *table::borrow(&module_store.name_to_token, domain_name);
        let token_object = object::address_to_object<Metadata>(token_addr);
        assert!(object::is_owner(token_object, addr), error::permission_denied(ENOT_OWNER));

        assert!(
            metadata::get_expiration_date(token_addr) > timestamp,
            error::permission_denied(ETOKEN_EXPIRED),
        );

        if (table::contains(&module_store.name_to_addr, domain_name)) {
            let removed_addr = table::remove(&mut module_store.name_to_addr, domain_name);
            table::remove(&mut module_store.addr_to_name, removed_addr);
        };

        if (table::contains(&module_store.addr_to_name, addr)) {
            let removed_name = table::remove(&mut module_store.addr_to_name, addr);
            table::remove(&mut module_store.name_to_addr, removed_name);
        };

        table::add(&mut module_store.name_to_addr, domain_name, addr);
        table::add(&mut module_store.addr_to_name, addr, domain_name);

        event::emit(
            SetEvent {
                addr,
                domain_name,
            },
        );
    }

    public entry fun extend_expiration(
        account: &signer,
        domain_name: String,
        duration: u64,
    ) acquires ModuleStore {
        let addr = signer::address_of(account);

        let module_store = borrow_global_mut<ModuleStore>(@usernames);
        domain_name = to_lower_case(&domain_name);
        let token = *table::borrow(&module_store.name_to_token, domain_name);

        assert!(
            duration >= module_store.config.min_duration,
            error::invalid_argument(EMIN_DURATION),
        );

        let (_height, timestamp) = block::get_block_info();
        let expiration_date = metadata::get_expiration_date(token);
        let new_expiration_date = if (expiration_date > timestamp) {
            expiration_date + duration
        } else {
            timestamp + duration
        };

        assert!(
            new_expiration_date - expiration_date <= MAX_EXPIRATION,
            error::invalid_argument(EMIN_DURATION),
        );

        metadata::update_expiration_date(token, new_expiration_date);
        let cost_amount = get_cost_amount(domain_name, duration);
        let module_store = borrow_global_mut<ModuleStore>(@usernames);
        let cost = primary_fungible_store::withdraw(account, get_init_metadata(), (cost_amount as u64));
        primary_fungible_store::deposit(module_store.pool, cost);

        event::emit<ExtendEvent>(
            ExtendEvent {
                addr,
                domain_name,
                expiration_date: new_expiration_date,
            },
        );
    }

    public entry fun update_records(
        account: &signer,
        domain_name: String,
        record_keys: vector<String>,
        record_values: vector<String>,
    ) acquires ModuleStore {
        let addr = signer::address_of(account);

        let module_store = borrow_global_mut<ModuleStore>(@usernames);
        domain_name = to_lower_case(&domain_name);
        let token = *table::borrow(&module_store.name_to_token, domain_name);
        let token_object = object::address_to_object<Metadata>(token);
        assert!(object::is_owner(token_object, addr), error::permission_denied(ENOT_OWNER));

        metadata::update_records(token, record_keys, record_values);

        event::emit(
            UpdateRecordsEvent {
                addr,
                domain_name,
                keys: record_keys,
                values: record_values,
            },
        );
    }

    public entry fun delete_records(
        account: &signer,
        domain_name: String,
        record_keys: vector<String>,
    ) acquires ModuleStore {
        let addr = signer::address_of(account);

        let module_store = borrow_global_mut<ModuleStore>(@usernames);
        domain_name = to_lower_case(&domain_name);
        let token = *table::borrow(&module_store.name_to_token, domain_name);
        let token_object = object::address_to_object<Metadata>(token);
        assert!(object::is_owner(token_object, addr), error::permission_denied(ENOT_OWNER));

        metadata::delete_records(token, record_keys);

        event::emit(
            DeleteRecordsEvent {
                addr,
                domain_name,
                keys: record_keys,
            },
        );
    }

    fun check_name(name: String) {
        let bytes = string::bytes(&name);
        let len = vector::length(bytes);
        assert!(len >= 3, error::invalid_argument(EMIN_NAME_LENGTH));
        assert!(len <= MAX_LENGTH, error::invalid_argument(EMIN_NAME_LENGTH));
        let index = 0;
        while (index < len) {
            let char = *vector::borrow(bytes, index);
            if (index == 0 || index == len - 1) {
                assert!(char != 45, error::invalid_argument(EINVALID_CHARACTOR))
            };
            assert!(
                char == 45 || // -
                (char >= 48 && char <= 57) || // 0 ~ 9
                (char >= 65 && char <= 90) || // A ~ Z
                (char >= 97 && char <= 122), // a ~ z
                error::invalid_argument(EINVALID_CHARACTOR),
            );

            index = index + 1;
        }
    }

    fun u64_to_string(num: u64): String {
        let num = num;
        let bytes: vector<u8> = vector[];

        while (num > 0) {
            let remain = (num % 10 as u8);
            num = num / 10;
            vector::push_back(&mut bytes, 48 + remain);
        };

        vector::reverse(&mut bytes);

        string::utf8(bytes)
    }

    fun get_cost_amount(domain_name: String, duration: u64): u64 acquires ModuleStore {
        let module_store = borrow_global_mut<ModuleStore>(@usernames);
        let len = string::length(&domain_name);
        let price_per_year = if (len == 3) {
            module_store.config.price_per_year_3char
        } else if (len == 4) {
            module_store.config.price_per_year_4char
        } else if (len < FREE_LENGTH) {
            module_store.config.price_per_year_default
        } else {
            0
        };

        let spot_price = dex::get_spot_price(object::address_to_object<PairConfig>(@pair), get_init_metadata());

        let usd_value = bigdecimal::from_ratio_u128((price_per_year as u128) * (duration as u128), (YEAR_TO_SECOND as u128));

        let bigdecimal_price = bigdecimal::div(
            usd_value,
            spot_price,
        );

        bigdecimal::truncate_u64(bigdecimal_price)
    }

    fun to_lower_case(str: &String): String {
        let bytes = *string::bytes(str);
        let len = vector::length(&bytes);
        let index = 0;
        while (index < len) {
            let char = vector::borrow_mut(&mut bytes, index);
            if (*char >= 65 && *char <= 90) {
                *char = *char + 32
            };
            index = index + 1;
        };

        return string::utf8(bytes)
    }

    fun is_expired(name: String): bool acquires ModuleStore {
        let token = *option::borrow(&get_valid_token(name));
        let expiration_date = metadata::get_expiration_date(token);
        let (_height, timestamp) = block::get_block_info();
        timestamp > expiration_date
    }

    fun get_init_metadata(): Object<CoinMetadata> {
        let init_symbol = string::utf8(b"uinit");
        coin::metadata(@initia_std, init_symbol)
    }

    #[test_only]
    struct CoinCapsInit has key {
        burn_cap: coin::BurnCapability,
        freeze_cap: coin::FreezeCapability,
        mint_cap: coin::MintCapability,
    }

    #[test_only]
    struct CoinCapsUsdc has key {
        burn_cap: coin::BurnCapability,
        freeze_cap: coin::FreezeCapability,
        mint_cap: coin::MintCapability,
    }

    #[test_only]
    fun initialized_coin(
        account: &signer,
        symbol: String,
    ): (coin::MintCapability, coin::BurnCapability, coin::FreezeCapability) {
        coin::initialize(
            account,
            option::none(),
            std::string::utf8(b"name"),
            symbol,
            6,
            string::utf8(b""),
            string::utf8(b""),
        )
    }

    #[test_only]
    fun deploy_dex(chain: &signer, lp_publisher: &signer) {
        primary_fungible_store::init_module_for_test();
        dex::init_module_for_test();
        let (usdc_mint_cap, usdc_burn_cap, usdc_freeze_cap) = initialized_coin(chain, string::utf8(b"USDC"));
        let (initia_mint_cap, initia_burn_cap, initia_freeze_cap) = initialized_coin(chain, string::utf8(b"uinit"));
        let lp_publisher_addr = signer::address_of(lp_publisher);
        let chain_addr = signer::address_of(chain);

        primary_fungible_store::deposit(lp_publisher_addr, coin::mint(&initia_mint_cap, 100000000));
        primary_fungible_store::deposit(lp_publisher_addr, coin::mint(&usdc_mint_cap, 100000000));
        
        // 1uinit == 10uusdc
        dex::create_pair_script(
            lp_publisher,
            std::string::utf8(b"name"),
            std::string::utf8(b"SYMBOL"),
            bigdecimal::from_ratio_u64(3, 1000),
            bigdecimal::from_ratio_u64(8, 10),
            bigdecimal::from_ratio_u64(2, 10),
            coin::metadata(chain_addr, string::utf8(b"uinit")),
            coin::metadata(chain_addr, string::utf8(b"USDC")),
            40000,
            100000,
        );

        move_to(chain, CoinCapsInit {
            burn_cap: initia_burn_cap,
            freeze_cap: initia_freeze_cap,
            mint_cap: initia_mint_cap,
        });

        move_to(chain, CoinCapsUsdc {
            burn_cap: usdc_burn_cap,
            freeze_cap: usdc_freeze_cap,
            mint_cap: usdc_mint_cap,
        });
    }

    #[test_only]
    fun init_mint_to(chain_addr: address, account: &signer, amount: u64) acquires CoinCapsInit {
        let caps = borrow_global<CoinCapsInit>(chain_addr);
        primary_fungible_store::deposit(signer::address_of(account), coin::mint(&caps.mint_cap, amount));
    }

    #[test_only]
    fun usdc_mint_to(chain_addr: address, account: &signer, amount: u64) acquires CoinCapsInit {
        let caps = borrow_global<CoinCapsInit>(chain_addr);
        primary_fungible_store::deposit(signer::address_of(account), coin::mint(&caps.mint_cap, amount));
    }

    #[test(chain = @0x1, source = @usernames, user1 = @0x2, user2 = @0x3, lp_publisher = @0x3)]
    fun end_to_end(
        chain: signer,
        source: signer,
        user1: signer,
        user2: signer,
        lp_publisher: signer,
    ) acquires CoinCapsInit, ModuleStore {
        deploy_dex(&chain, &lp_publisher);
        let chain_addr = signer::address_of(&chain);
        let addr1 = signer::address_of(&user1);
        let addr2 = signer::address_of(&user2);
        init_mint_to(chain_addr, &user1, 100);
        init_mint_to(chain_addr, &user2, 100);

        initialize(
            &source,
            100,
            50,
            10,
            1209600,
            1209600,
            string::utf8(b"https://test.com/"),
            string::utf8(b"https://test.com/"),
        );


        std::block::set_block_info(100, 100);

        register_domain(&user1, string::utf8(b"abc"), 31557600);
        assert!(primary_fungible_store::balance(addr1, get_init_metadata()) == 90, 0);

        register_domain(&user1, string::utf8(b"abcd"), 31557600);
        assert!(primary_fungible_store::balance(addr1, get_init_metadata()) == 85, 0);

        register_domain(&user1, string::utf8(b"abcde"), 31557600);
        assert!(primary_fungible_store::balance(addr1, get_init_metadata()) == 84, 0);

        register_domain(&user1, string::utf8(b"abcdefghijk"), 31557600);
        assert!(primary_fungible_store::balance(addr1, get_init_metadata()) == 84, 0);

        let token = *option::borrow(&get_valid_token(string::utf8(b"abc")));
        let token_object = object::address_to_object<Metadata>(token);
        assert!(initia_std::nft::token_id(token_object) == string::utf8(b"abc.init:100"), 0);

        set_name(&user1, string::utf8(b"abcd"));
        assert!(get_name_from_address(addr1) == option::some(string::utf8(b"abcd")), 0);
        assert!(get_address_from_name(string::utf8(b"abcd")) == option::some(addr1), 0);

        set_name(&user1, string::utf8(b"abc"));
        assert!(get_name_from_address(addr1) == option::some(string::utf8(b"abc")), 0);
        assert!(get_address_from_name(string::utf8(b"abc")) == option::some(addr1), 0);

        extend_expiration(&user1, string::utf8(b"abcd"), 31557600);
        assert!(primary_fungible_store::balance(addr1, get_init_metadata()) == 79, 0);

        std::block::set_block_info(200, 100 + 31557600 + 1209600 + 1);
        register_domain(&user2, string::utf8(b"abc"), 31557600);

        set_name(&user2, string::utf8(b"abc"));
        assert!(get_name_from_address(addr2) == option::some(string::utf8(b"abc")), 0);
        assert!(get_address_from_name(string::utf8(b"abc")) == option::some(addr2), 0);

        set_name(&user1, string::utf8(b"abcd"));
        assert!(get_name_from_address(addr1) == option::some(string::utf8(b"abcd")), 0);
        assert!(get_address_from_name(string::utf8(b"abcd")) == option::some(addr1), 0);

        update_records(
            &user1,
            string::utf8(b"abcd"),
            vector[string::utf8(b"height"), string::utf8(b"weight")],
            vector[string::utf8(b"190cm"), string::utf8(b"80kg")]
        );

        delete_records(
             &user1,
            string::utf8(b"abcd"),
            vector[string::utf8(b"weight")],
        )
    }

    #[test(chain = @0x1, source = @usernames, user = @0x2, lp_publisher = @0x3)]
    fun query_test(
        chain: signer,
        source: signer,
        user: signer,
        lp_publisher: signer,
    ) acquires CoinCapsInit, ModuleStore {
        deploy_dex(&chain, &lp_publisher);

        let addr = signer::address_of(&user);
        init_mint_to(signer::address_of(&chain), &user, 100);

        initialize(
            &source,
            100,
            50,
            10,
            1000,
            1000,
            string::utf8(b"https://test.com/"),
            string::utf8(b"https://test.com/"),
        );

        std::block::set_block_info(100, 100);

        // before register
        assert!(get_name_from_address(addr) == option::none(), 0);
        assert!(get_address_from_name(string::utf8(b"abcd")) == option::none(), 1);
        assert!(get_valid_token(string::utf8(b"abcd")) == option::none(), 2);

        register_domain(&user, string::utf8(b"abcd"), 1000);
        let token = *option::borrow(&get_valid_token(string::utf8(b"abcd")));
        let token_object = object::address_to_object<Metadata>(token);
        assert!(initia_std::nft::token_id(token_object) == string::utf8(b"abcd.init:100"), 3);
        set_name(&user, string::utf8(b"abcd"));
        assert!(get_name_from_address(addr) == option::some(string::utf8(b"abcd")), 4);
        assert!(get_address_from_name(string::utf8(b"abcd")) == option::some(addr), 5);

        // after expired
        std::block::set_block_info(110, 1110);
        let token = *option::borrow(&get_valid_token(string::utf8(b"abcd")));
        let token_object = object::address_to_object<Metadata>(token);
        assert!(initia_std::nft::token_id(token_object) == string::utf8(b"abcd.init:100"), 6);
        assert!(get_name_from_address(addr) == option::none(), 7);
        assert!(get_address_from_name(string::utf8(b"abcd")) == option::none(), 8);

        // after extend
        extend_expiration(&user, string::utf8(b"abcd"), 1000);
        let token = *option::borrow(&get_valid_token(string::utf8(b"abcd")));
        let token_object = object::address_to_object<Metadata>(token);
        assert!(initia_std::nft::token_id(token_object) == string::utf8(b"abcd.init:100"), 9);
        assert!(get_name_from_address(addr) == option::some(string::utf8(b"abcd")), 10);
        assert!(get_address_from_name(string::utf8(b"abcd")) == option::some(addr), 11);
    }

    #[test]
    fun test_to_lower_case() {
        let name = string::utf8(b"AbCd");
        assert!(to_lower_case(&name) == string::utf8(b"abcd"), 0);
    }
}
