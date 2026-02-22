import "package:flutter/material.dart";
import "package:flutter_tabler_icons/flutter_tabler_icons.dart";
import "package:inventree/widget/progress.dart";

import "package:inventree/api.dart";
import "package:inventree/l10.dart";
import "package:inventree/inventree/build.dart";

/*
 * A widget for displaying a single build order in a list
 */
class BuildOrderListItem extends StatelessWidget {
  const BuildOrderListItem(this.order, {Key? key}) : super(key: key);

  final InvenTreeBuildOrder order;

  @override
  Widget build(BuildContext context) {
    // Calculate completion percentage
    double progress = 0;
    if (order.quantity > 0) {
      progress = order.completed / order.quantity;
    }

    // Clamp to valid range
    progress = progress.clamp(0, 1);

    // Part name may be empty
    String partName = order.partDetail?.name ?? "-";

    // Format dates
    String creationDate = order.creationDate;
    String targetDate = order.targetDate.isNotEmpty ? order.targetDate : "-";

    return Card(
      margin: const EdgeInsets.all(4.0),
      child: InkWell(
        onTap: () {
          order.goToDetailPage(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with reference and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.reference,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    decoration: BoxDecoration(
                      color: BuildOrderStatus.getStatusColor(
                        order.status,
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      BuildOrderStatus.getStatusText(order.status),
                      style: TextStyle(
                        color: BuildOrderStatus.getStatusColor(order.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Part information
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child:
                        order.partDetail != null &&
                            order.partDetail!.thumbnail.isNotEmpty
                        ? InvenTreeAPI().getThumbnail(
                            order.partDetail!.thumbnail,
                          )
                        : const Icon(TablerIcons.tool),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (order.description.isNotEmpty)
                          Text(
                            order.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Progress indicator
              ProgressBar(order.completed, maximum: order.quantity),

              const SizedBox(height: 8),

              // Date information
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(TablerIcons.calendar, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${L10().creationDate}: ${creationDate}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(TablerIcons.calendar_due, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${L10().targetDate}: $targetDate",
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              (order.targetDate.isNotEmpty &&
                                  DateTime.tryParse(order.targetDate) != null &&
                                  DateTime.tryParse(
                                    order.targetDate,
                                  )!.isBefore(DateTime.now()))
                              ? Colors.red
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
