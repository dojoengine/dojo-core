use dojo::meta::{Layout, introspect::Ty};

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub enum ModelIndex {
    Keys: Span<felt252>,
    Id: felt252,
    // (entity_id, member_id)
    MemberId: (felt252, felt252)
}

pub trait ModelDefinition<T> {
    fn name() -> ByteArray;
    fn namespace() -> ByteArray;
    fn tag() -> ByteArray;
    
    fn version() -> u8;
    fn selector() -> felt252;
    fn name_hash() -> felt252;
    fn namespace_hash() -> felt252;
    
    fn layout() -> Layout;
    fn schema() -> Ty;
    fn size() -> Option<usize>;
}


#[derive(Drop, Serde, Debug, PartialEq)]
pub struct ModelDef {
    pub name: ByteArray,
    pub namespace: ByteArray,

    pub version: u8,
    pub selector: felt252,
    pub name_hash: felt252,
    pub namespace_hash: felt252,
    
    pub layout: Layout,
    pub schema: Ty,
    pub packed_size: Option<usize>,
    pub unpacked_size: Option<usize>,
}
