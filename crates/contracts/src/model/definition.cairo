use dojo::meta::{Layout, introspect::Ty};

/// The `ModelIndex` provides encapsulation for different ways to access
/// a model's data.
///
/// - `Keys`: Access by keys, where each individual key is known, and can be hashed.
/// - `Id`: Access by id, where only the id of the entity is known (keys already hashed).
/// - `MemberId`: Access by member id, where the member id and entity id are known.
#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub enum ModelIndex {
    Keys: Span<felt252>,
    Id: felt252,
    // (entity_id, member_id)
    MemberId: (felt252, felt252)
}

/// The `ModelDefinition` trait.
///
/// Definition of the model containing all the fields that makes up a model.
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
