# Fork reasoning

IMCollectionView was sometimes hanging the app with driving the CPU over 100% when keyboard was poping up and layout was changing. The problem was in the imoji rendering function, more specifically this batch of code:

```
[self performBatchUpdates:^{
    [self reloadItemsAtIndexPaths:@[newPath]];
} completion:nil];
```

We changed the batch updates code with performing actions on the cells themselves which seems to work just fine. As this is a hacky way of solving this problem which is probably a very isolated case pertaining just us, we will not issue a pull request. However we notified the Imoji team and as soon as they have fixed this properly, we can switch back to ther version.
