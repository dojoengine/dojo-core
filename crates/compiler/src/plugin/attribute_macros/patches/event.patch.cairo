#[generate_trait]
pub impl $type_name$EmitterImpl of $type_name$Emitter {
    fn emit(self: @$type_name$, world: dojo::world::IWorldDispatcher) {
        dojo::event::Event::<$type_name$>::emit(self, world);
    }
}

pub impl $type_name$EventImpl of dojo::event::Event<$type_name$> {

    fn emit(self: @$type_name$, world: dojo::world::IWorldDispatcher) {
        dojo::world::IWorldDispatcherTrait::emit_event(
            world,
            Self::selector(),
            Self::keys(self),
            Self::values(self),
            Self::historical()
        );
    }

    #[inline(always)]
    fn name() -> ByteArray {
        "$type_name$"
    }

    #[inline(always)]
    fn namespace() -> ByteArray {
        "$event_namespace$"
    }

    #[inline(always)]
    fn tag() -> ByteArray {
        "$event_tag$"
    }

    #[inline(always)]
    fn version() -> u8 {
        $event_version$
    }

    #[inline(always)]
    fn selector() -> felt252 {
        $event_selector$
    }

    #[inline(always)]
    fn instance_selector(self: @$type_name$) -> felt252 {
        Self::selector()
    }

    #[inline(always)]
    fn name_hash() -> felt252 {
        $event_name_hash$
    }

    #[inline(always)]
    fn namespace_hash() -> felt252 {
        $event_namespace_hash$
    }

    #[inline(always)]
    fn definition() -> dojo::event::EventDefinition {
        dojo::event::EventDefinition {
            name: Self::name(),
            namespace: Self::namespace(),
            namespace_selector: Self::namespace_hash(),
            version: Self::version(),
            layout: Self::layout(),
            schema: Self::schema()
        }
    }

    #[inline(always)]
    fn layout() -> dojo::meta::Layout {
        dojo::meta::introspect::Introspect::<$type_name$>::layout()
    }

    #[inline(always)]
    fn schema() -> dojo::meta::introspect::Ty {
        dojo::meta::introspect::Introspect::<$type_name$>::ty()
    }

    #[inline(always)]
    fn historical() -> bool {
        $event_historical$
    }

    #[inline(always)]
    fn keys(self: @$type_name$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_keys$
        core::array::ArrayTrait::span(@serialized)
    }

    #[inline(always)]
    fn values(self: @$type_name$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }
}

#[cfg(target: "test")]
pub impl $type_name$EventImplTest of dojo::event::EventTest<$type_name$> {
    fn emit_test(self: @$type_name$, world: dojo::world::IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: 
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::emit_event_test(
            world_test,
            dojo::event::Event::<$type_name$>::selector(),
            dojo::event::Event::<$type_name$>::keys(self),
            dojo::event::Event::<$type_name$>::values(self),
            dojo::event::Event::<$type_name$>::historical()
        );
    }
}

#[starknet::contract]
pub mod $contract_name$ {
    use super::$type_name$;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl DojoEventImpl of dojo::event::IEvent<ContractState>{
        fn name(self: @ContractState) -> ByteArray {
           "$type_name$"
        }

        fn namespace(self: @ContractState) -> ByteArray {
           "$event_namespace$"
        }

        fn tag(self: @ContractState) -> ByteArray {
            "$event_tag$"
        }

        fn version(self: @ContractState) -> u8 {
           $event_version$
        }

        fn selector(self: @ContractState) -> felt252 {
           $event_selector$
        }

        fn name_hash(self: @ContractState) -> felt252 {
            $event_name_hash$
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            $event_namespace_hash$
        }

        fn definition(self: @ContractState) -> dojo::event::EventDefinition {
            dojo::event::Event::<$type_name$>::definition()
        }

        fn layout(self: @ContractState) -> dojo::meta::Layout {
            dojo::event::Event::<$type_name$>::layout()
        }

        fn schema(self: @ContractState) -> dojo::meta::introspect::Ty {
            dojo::meta::introspect::Introspect::<$type_name$>::ty()
        }
    }
}
