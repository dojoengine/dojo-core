pub mod contract {
    mod base_contract;
    pub use base_contract::base;
    pub mod contract;
    pub use contract::{IContract, IContractDispatcher, IContractDispatcherTrait};
    pub mod upgradeable;
}

pub mod event {
    pub mod event;
    pub use event::{Event, IEvent, IEventDispatcher, IEventDispatcherTrait};

    #[cfg(target: "test")]
    pub use event::{EventTest};
}

pub mod meta {
    pub mod introspect;
    pub use introspect::Introspect;
    
    pub mod layout;
    pub use layout::{Layout, FieldLayout};
}

pub mod model {
    pub mod attributes;
    pub use attributes::{ModelIndex, ModelAttributes};

    pub mod members;
    pub use members::{MemberStore};

    pub mod model;
    pub use model::{ModelStore};

    pub mod entity;
    pub use entity::{EntityStore};

    pub mod interface;
    pub use interface::{IModel, IModelDispatcher, IModelDispatcherTrait};
    
    pub mod metadata;
    pub use metadata::{ResourceMetadata, resource_metadata};
    pub(crate) use metadata::{initial_address, initial_class_hash};

    #[cfg(target: "test")]
    pub use model::{ModelTest, ModelEntityTest};
}

pub(crate) mod storage {
    pub(crate) mod database;
    pub(crate) mod packing;
    pub(crate) mod layout;
    pub(crate) mod storage;
}

pub mod utils {
    // Since Scarb 2.6.0 there's an optimization that does not
    // build tests for dependencies and it's not configurable.
    //
    // To expose correctly the test utils for a package using dojo-core,
    // we need to it in the `lib` target or using the `#[cfg(target: "test")]`
    // attribute.
    //
    // Since `test_utils` is using `TEST_CLASS_HASH` to factorize some deployment
    // core, we place it under the test target manually.
    #[cfg(target: "test")]
    pub mod test;

    pub mod utils;
    pub use utils::{
        bytearray_hash, entity_id_from_keys, find_field_layout, find_model_field_layout, any_none,
        sum, combine_key, selector_from_names,
    };

    pub mod descriptor;
    pub use descriptor::{
        Descriptor, DescriptorTrait, IDescriptorDispatcher, IDescriptorDispatcherTrait
    };
}

pub mod world {
    pub(crate) mod update;
    pub(crate) mod config;
    pub(crate) mod errors;

    mod world_contract;
    pub use world_contract::{
        world, IWorld, IWorldDispatcher, IWorldDispatcherTrait, IWorldProvider,
        IWorldProviderDispatcher, IWorldProviderDispatcherTrait, Resource,
    };
    pub(crate) use world_contract::{
        IUpgradeableWorld, IUpgradeableWorldDispatcher, IUpgradeableWorldDispatcherTrait
    };

    #[cfg(target: "test")]
    pub use world_contract::{IWorldTest, IWorldTestDispatcher, IWorldTestDispatcherTrait};
}

#[cfg(test)]
mod tests {
    mod meta {
        mod introspect;
    }

    mod model {
        mod model;
    }
    mod storage {
        mod database;
        mod packing;
        mod storage;
    }
    mod base;
    mod benchmarks;
    mod expanded {
        pub(crate) mod selector_attack;
    }
    mod helpers;
    mod world {
        mod acl;
        mod entities;
        mod resources;
        mod world;
    }
    mod utils;
}
