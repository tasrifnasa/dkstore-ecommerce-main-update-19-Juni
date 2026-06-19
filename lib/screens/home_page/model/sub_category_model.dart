
import 'package:dkstore/config/helper.dart';

class SubCategoriesResponse {
  final bool? success;
  final String? message;
  final SubCategoriesPageData? data;

  SubCategoriesResponse({
    this.success,
    this.message,
    this.data,
  });

  factory SubCategoriesResponse.fromJson(Map<String, dynamic> json) {
    return SubCategoriesResponse(
      success: parseBool(json['success']),
      message: parseString(json['message']),
      data: json['data'] != null ? SubCategoriesPageData.fromJson(json['data']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'message': message,
    if (data != null) 'data': data!.toJson(),
  };
}

class SubCategoriesPageData {
  final int? currentPage;
  final int? lastPage;
  final int? perPage;
  final int? total;
  final List<SubCategoryData> subCategories;

  SubCategoriesPageData({
    this.currentPage,
    this.lastPage,
    this.perPage,
    this.total,
    this.subCategories = const [],
  });

  factory SubCategoriesPageData.fromJson(Map<String, dynamic> json) {
    return SubCategoriesPageData(
      currentPage: parseInt(json['current_page']),
      lastPage: parseInt(json['last_page']),
      perPage: parseInt(json['per_page']),
      total: parseInt(json['total']),
      subCategories: _parseSubCategoryList(json['data']),
    );
  }

  Map<String, dynamic> toJson() => {
    'current_page': currentPage,
    'last_page': lastPage,
    'per_page': perPage,
    'total': total,
    'data': subCategories.map((e) => e.toJson()).toList(),
  };

  static List<SubCategoryData> _parseSubCategoryList(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(SubCategoryData.fromJson)
        .toList();
  }
}

/// Unified subcategory model
class SubCategoryData {
  final int? id;
  final String? title;
  final String? slug;
  final String? image;
  final String? banner;
  final String? icon;
  final String? activeIcon;
  final String? backgroundType;
  final String? backgroundColor;
  final String? backgroundImage;
  final int? parentId;
  final String? description;
  final String? status;
  final bool? requiresApproval;
  final Object? metadata;
  final int? subcategoryCount;
  final int? productCount;

  SubCategoryData({
    this.id,
    this.title,
    this.slug,
    this.image,
    this.banner,
    this.icon,
    this.activeIcon,
    this.backgroundType,
    this.backgroundColor,
    this.backgroundImage,
    this.parentId,
    this.description,
    this.status,
    this.requiresApproval,
    this.metadata,
    this.subcategoryCount,
    this.productCount,
  });

  factory SubCategoryData.fromJson(Map<String, dynamic> json) {
    return SubCategoryData(
      id: parseInt(json['id']),
      title: parseString(json['title']),
      slug: parseString(json['slug']),
      image: parseString(json['image']),
      banner: parseString(json['banner']),
      icon: parseString(json['icon']),
      activeIcon: parseString(json['active_icon']),
      backgroundType: parseString(json['background_type']),
      backgroundColor: parseString(json['background_color']),
      backgroundImage: parseString(json['background_image']),
      parentId: parseInt(json['parent_id']),
      description: parseString(json['description']),
      status: parseString(json['status']),
      requiresApproval: parseBool(json['requires_approval']),
      metadata: json['metadata'],
      subcategoryCount: parseInt(json['subcategory_count']),
      productCount: parseInt(json['product_count']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'slug': slug,
    'image': image,
    'banner': banner,
    'icon': icon,
    'active_icon': activeIcon,
    'background_type': backgroundType,
    'background_color': backgroundColor,
    'background_image': backgroundImage,
    'parent_id': parentId,
    'description': description,
    'status': status,
    'requires_approval': requiresApproval,
    'metadata': metadata,
    'subcategory_count': subcategoryCount,
    'product_count': productCount,
  };
}