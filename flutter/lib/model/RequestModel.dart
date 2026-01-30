class ApiResponse<T> {
  final int code;
  final String msg;
  final T data;
  final int? count;

  ApiResponse({
    required this.code,
    required this.msg,
    required this.data,
    this.count,
  });

  factory ApiResponse.fromJson(
      Map<String, dynamic> json,
      T Function(dynamic raw) fromData,
      ) {
    return ApiResponse<T>(
      code: (json['Code'] as num).toInt(),
      msg: (json['msg'] ?? '') as String,
      data: fromData(json['data']),
      count: (json['count'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson(Object Function(T value) toData) {
    return {
      'Code': code,
      'msg': msg,
      'data': toData(data),
      'count': count,
    };
  }
}
