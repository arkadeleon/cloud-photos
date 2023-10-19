//
//  AccountCollectionViewController.swift
//  S3Photos
//
//  Created by Leon Li on 2023/10/18.
//

import CoreData
import UIKit

class AccountCollectionViewController: UIViewController {

    private var collectionView: UICollectionView!
    private var diffableDataSource: UICollectionViewDiffableDataSource<Int, NSManagedObjectID>!
    private var fetchedResultsController: NSFetchedResultsController<S3Account>!

    override func viewDidLoad() {
        super.viewDidLoad()

        let listConfiguration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        let listLayout = UICollectionViewCompositionalLayout.list(using: listConfiguration)

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: listLayout)
        collectionView.delegate = self
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, NSManagedObjectID> { cell, indexPath, objectID in
            let account = PersistenceController.shared.container.viewContext.object(with: objectID) as! S3Account

            var contentConfiguration = cell.defaultContentConfiguration()
            contentConfiguration.image = UIImage(systemName: "person.circle")
            contentConfiguration.text = """
            \(account.accessKeyId!)
            \(account.secretAccessKey!.map({ _ in "*" }).joined())
            \(account.endpoint!)
            \(account.bucket!)
            """

            cell.contentConfiguration = contentConfiguration
        }

        diffableDataSource = UICollectionViewDiffableDataSource<Int, NSManagedObjectID>(collectionView: collectionView) { collectionView, indexPath, objectID in
            let account = PersistenceController.shared.container.viewContext.object(with: objectID) as! S3Account
            let cell = collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: objectID)
            cell.accessories = account.isActive ? [.checkmark()] : []
            return cell
        }
        collectionView.dataSource = diffableDataSource

        view.addSubview(collectionView)

        let fetchRequest = NSFetchRequest<S3Account>(entityName: "S3Account")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "objectID", ascending: true)]

        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: PersistenceController.shared.container.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()
    }
}

extension AccountCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let objectIDs = diffableDataSource.snapshot().itemIdentifiers
        let selectedObjectID = diffableDataSource.itemIdentifier(for: indexPath)

        for objectID in objectIDs {
            let account = PersistenceController.shared.container.viewContext.object(with: objectID) as! S3Account
            account.isActive = objectID == selectedObjectID
        }

        PersistenceController.shared.saveContext()

        collectionView.deselectItem(at: indexPath, animated: true)
    }
}

extension AccountCollectionViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChangeContentWith snapshot: NSDiffableDataSourceSnapshotReference) {
        guard let dataSource = collectionView?.dataSource as? UICollectionViewDiffableDataSource<Int, NSManagedObjectID> else {
            assertionFailure("The data source has not implemented snapshot support while it should")
            return
        }
        var snapshot = snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>
        let currentSnapshot = dataSource.snapshot() as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>

        let reloadIdentifiers: [NSManagedObjectID] = snapshot.itemIdentifiers.compactMap { itemIdentifier in
            guard let currentIndex = currentSnapshot.indexOfItem(itemIdentifier), let index = snapshot.indexOfItem(itemIdentifier), index == currentIndex else {
                return nil
            }
            guard let existingObject = try? controller.managedObjectContext.existingObject(with: itemIdentifier), existingObject.isUpdated else { return nil }
            return itemIdentifier
        }
        snapshot.reloadItems(reloadIdentifiers)

        let shouldAnimate = collectionView?.numberOfSections != 0
        dataSource.apply(snapshot as NSDiffableDataSourceSnapshot<Int, NSManagedObjectID>, animatingDifferences: shouldAnimate)
    }
}
