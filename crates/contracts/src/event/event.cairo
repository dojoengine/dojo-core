use dojo::meta::Layout;
use dojo::meta::introspect::Ty;
use dojo::world::IWorldDispatcher;

pub trait Event<T> {
    fn emit(self: @T, world: IWorldDispatcher);

    fn name() -> ByteArray;
    fn namespace() -> ByteArray;
    fn tag() -> ByteArray;

    fn version() -> u8;

    fn selector() -> felt252;
    fn instance_selector(self: @T) -> felt252;

    fn name_hash() -> felt252;
    fn namespace_hash() -> felt252;

    fn layout() -> Layout;
    fn schema(self: @T) -> Ty;

    fn packed_size() -> Option<usize>;
    fn unpacked_size() -> Option<usize>;

    fn historical() -> bool;
    fn keys(self: @T) -> Span<felt252>;
    fn values(self: @T) -> Span<felt252>;
}

#[starknet::interface]
pub trait IEvent<T> {
    fn name(self: @T) -> ByteArray;
    fn namespace(self: @T) -> ByteArray;
    fn tag(self: @T) -> ByteArray;

    fn version(self: @T) -> u8;

    fn selector(self: @T) -> felt252;
    fn name_hash(self: @T) -> felt252;
    fn namespace_hash(self: @T) -> felt252;

    fn packed_size(self: @T) -> Option<usize>;
    fn unpacked_size(self: @T) -> Option<usize>;

    fn layout(self: @T) -> Layout;
    fn schema(self: @T) -> Ty;
}
