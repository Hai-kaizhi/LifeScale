package com.lifescale.backend.common.exception;

/**
 * 实体未找到时抛出。
 */
public class EntityNotFoundException extends RuntimeException {

    public EntityNotFoundException(String message) {
        super(message);
    }

    public EntityNotFoundException(String entityName, Object id) {
        super(entityName + " not found: " + id);
    }
}
