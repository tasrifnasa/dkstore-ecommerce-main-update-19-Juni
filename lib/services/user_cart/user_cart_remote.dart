import 'package:flutter/foundation.dart';
import 'package:dkstore/config/api_routes.dart';

import '../../config/helper.dart';

class CartRemoteRepository {
  Future<Map<String, dynamic>> addItemToCart({
    required int productVariantId,
    required int storeId,
    required int quantity,
    required bool replaceQty
  }) async {
    debugPrint(
        '[API] ADD → variant:$productVariantId store:$storeId qty:$quantity');

    final response = await AppHelpers.apiBaseHelper.postAPICall(
      ApiRoutes.addToCartApi,
      {
        'product_variant_id': productVariantId,
        'store_id': storeId,
        'quantity': quantity,
        'replace_quantity': replaceQty
      },
    );

    return response.data;
  }

  Future<void> updateItemQuantity({
    required int cartItemId,
    required int quantity,
  }) async {
    debugPrint('[API] UPDATE → cartItemId:$cartItemId qty:$quantity');

    await AppHelpers.apiBaseHelper.postAPICall(
      ApiRoutes.removeItemFromCartApi + cartItemId.toString(),
      {'quantity': quantity},
    );
  }

  Future<void> removeItemFromCart({
    required int cartItemId,
  }) async {
    debugPrint('[API] DELETE → cartItemId:$cartItemId');

    await AppHelpers.apiBaseHelper.deleteAPICall(
      ApiRoutes.removeItemFromCartApi + cartItemId.toString(),
      {},
    );
  }
}
