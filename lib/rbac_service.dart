import 'api_client.dart';
import 'data_utils.dart';

class RbacService {
  RbacService(this._api);

  final ApiClient _api;

  List<Map<String, dynamic>> _dataList(Object? response) {
    final map = readMap(response);
    return readList(map['data'] ?? response);
  }

  Future<List<Map<String, dynamic>>> roles() async {
    return _dataList(await _api.get('/rbac/roles/'));
  }

  Future<Map<String, dynamic>> createRole(Map<String, dynamic> payload) async {
    return readMap(await _api.post('/rbac/roles/', payload, authorized: true));
  }

  Future<List<Map<String, dynamic>>> permissionGroups() async {
    return _dataList(await _api.get('/rbac/permission-groups/'));
  }

  Future<List<Map<String, dynamic>>> permissions() async {
    return _dataList(await _api.get('/rbac/permissions/'));
  }

  Future<List<Map<String, dynamic>>> rolePermissions(String roleUuid) async {
    return _dataList(await _api.get('/rbac/roles/$roleUuid/permissions/'));
  }

  Future<void> assignRolePermission(String roleUuid, String permissionUuid) async {
    await _api.post(
      '/rbac/roles/$roleUuid/permissions/',
      {'permission_uuid': permissionUuid},
      authorized: true,
    );
  }

  Future<void> removeRolePermission(String roleUuid, String permissionUuid) async {
    await _api.delete('/rbac/roles/$roleUuid/permissions/$permissionUuid/');
  }

  Future<List<Map<String, dynamic>>> userRoles() async {
    return _dataList(await _api.get('/rbac/user-roles/'));
  }

  Future<void> assignUserRole({
    required int user,
    required int role,
    int? store,
  }) async {
    await _api.post('/rbac/user-roles/assign/', {
      'user': user,
      'role': role,
      'store': store,
      'is_active': true,
    }, authorized: true);
  }

  Future<void> deleteUserRole(String uuid) async {
    await _api.delete('/rbac/user-roles/$uuid/');
  }
}
