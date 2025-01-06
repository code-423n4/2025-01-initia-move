module usernames::metadata {
    use std::string::String;
    use std::vector;
    use std::error;

    use initia_std::object;
    use initia_std::nft::{Self, Nft};

    const MAX_RECORD: u64 = 10;

    const ELENGTH_MISMATCH: u64 = 0;
    const EMAX_RECORD_EXCEED: u64 = 1;
    const EKEY_NOT_FOUND: u64 = 2;

    friend usernames::usernames;

    struct Metadata has key {
        expiration_date: u64,
        name: String,
        record_keys: vector<String>,
        record_values: vector<String>,
    }

    struct TokenInfoResponse {
        token_id: address,
        token_uri: String,
        extension: MetadataResponse,
    }

    struct MetadataResponse has drop {
        expiration_date: u64,
        name: String,
        record_keys: vector<String>,
        record_values: vector<String>,
    }

    #[view]
    public fun get_metadata(addr: address): MetadataResponse acquires Metadata {
        let metadata = borrow_global<Metadata>(addr);
        MetadataResponse {
            expiration_date: metadata.expiration_date,
            name: metadata.name,
            record_keys: metadata.record_keys,
            record_values: metadata.record_values,
        }
    }

    #[view]
    public fun get_token_info(addr: address): TokenInfoResponse acquires Metadata {
        let metadata = borrow_global<Metadata>(addr);
        TokenInfoResponse {
            token_id: addr,
            token_uri: nft::uri(object::address_to_object<Nft>(addr)),
            extension: MetadataResponse {
                expiration_date: metadata.expiration_date,
                name: metadata.name,
                record_keys: metadata.record_keys,
                record_values: metadata.record_values,
            }
        }
    }

    public(friend) fun create(
        token: &signer,
        expiration_date: u64,
        name: String,
        record_keys: vector<String>,
        record_values: vector<String>,
    ) {
        move_to(
            token,
            Metadata {
                expiration_date,
                name,
                record_keys,
                record_values,
            },
        )

    }

    public(friend) fun update_expiration_date(
        token: address,
        new_expiration_date: u64,
    ) acquires Metadata {
        let metadata = borrow_global_mut<Metadata>(token);
        metadata.expiration_date = new_expiration_date;
    }

    public(friend) fun update_records(
        token: address,
        record_keys: vector<String>,
        record_values: vector<String>,
    ) acquires Metadata {
        let metadata = borrow_global_mut<Metadata>(token);
        let key_length = vector::length(&record_keys);
        let value_length = vector::length(&record_values);
        assert!(key_length == value_length, error::invalid_argument(ELENGTH_MISMATCH));
        let index = 0;
        while(index < key_length) {
            let (e, i) = vector::index_of(&metadata.record_keys, vector::borrow(&record_keys, index));
            if (e) {
                let value = vector::borrow_mut(&mut metadata.record_values, i);
                *value = *vector::borrow(&record_values, index);
            } else {
                vector::push_back(&mut metadata.record_keys, *vector::borrow(&record_keys, index));
                vector::push_back(&mut metadata.record_values, *vector::borrow(&record_values, index));
            };
            index = index + 1;
        };

        assert!(vector::length(&metadata.record_keys) <= MAX_RECORD, error::invalid_state(EMAX_RECORD_EXCEED));
    }

    public (friend) fun delete_records(
        token: address,
        record_keys: vector<String>,
    ) acquires Metadata {
        let metadata = borrow_global_mut<Metadata>(token);
        let length = vector::length(&record_keys);
        let index = 0;
        while(index < length) {
            let (e, i) = vector::index_of(&metadata.record_keys, vector::borrow(&record_keys, index));
            assert!(e, error::not_found(EKEY_NOT_FOUND));
            vector::remove(&mut metadata.record_keys, i);
            vector::remove(&mut metadata.record_values, i);
            index = index + 1;
        };
    }

    public fun get_expiration_date(token: address): u64 acquires Metadata {
        let metadata = borrow_global<Metadata>(token);
        metadata.expiration_date
    }
}