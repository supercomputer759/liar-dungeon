class_name PlayerInventory
extends Node

signal changed
const SLOT_COUNT := 4
var slots: Array = [null, null, null, null]

func clear() -> void:
	slots = [null, null, null, null]
	changed.emit()

func get_slot(index: int) -> RefCounted:
	return slots[index] as RefCounted if index >= 0 and index < SLOT_COUNT else null

func add_item(item: RefCounted) -> bool:
	for existing in slots:
		if existing != null and existing.definition.item_id == item.definition.item_id and existing.quantity < existing.definition.maximum_stack:
			existing.quantity += 1
			changed.emit()
			return true
	for index in SLOT_COUNT:
		if slots[index] == null:
			slots[index] = item
			changed.emit()
			return true
	return false

func consume_slot(index: int) -> void:
	var item := get_slot(index)
	if item == null: return
	item.quantity -= 1
	if item.quantity <= 0: slots[index] = null
	changed.emit()
